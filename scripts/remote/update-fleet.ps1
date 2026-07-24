<#
.SYNOPSIS
    Runs the deployment update payload (update-server.sh) on every server in a
    list, sequentially, over ssh - and prints a per-server summary at the end.

.DESCRIPTION
    For each server in the list (default: servers.txt next to this script),
    this script streams update-server.sh to 'bash -s' over ssh using key-based
    auth, parses the PF|... markers the payload emits, and writes:

      - a per-server log file under <ReportDir>\<timestamp>\
      - a summary.csv in the same folder
      - a console summary table

    A failure on one server never stops the run. Only the built-in Windows
    OpenSSH client is required (no admin rights, no extra software).
    Run install-ssh-key.ps1 once first to set up key-based auth.

    Press Ctrl+C during a run to stop gracefully: the server being updated
    finishes, the remaining servers are marked SKIPPED, and the summary and
    per-server logs are still written.

    Statuses:
      OK          - updated, all containers up
      WARN        - updated, but something needs attention (non-standard image
                    tags, degraded containers, missing proxy script)
      FAIL        - a step failed on the server (see Detail and the log file)
      UNREACHABLE - ssh could not connect
      SKIPPED     - not attempted; the run was cancelled with Ctrl+C

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\update-fleet.ps1

.EXAMPLE
    .\update-fleet.ps1 -DryRun
    Connectivity / pending-changes check only; nothing is modified on servers.

.EXAMPLE
    .\update-fleet.ps1 -ServerList .\just-one-server.txt -HealthDelaySec 30

.NOTES
    Exit codes: 0 = all servers OK/WARN, 1 = at least one FAIL/UNREACHABLE,
    2 = preflight error. With -FailOnWarn, WARN also causes exit 1.
#>
[CmdletBinding()]
param(
    [string]$ServerList,
    [string]$User = 'pacefactory',
    [string]$KeyPath = (Join-Path $env:USERPROFILE '.ssh\pf_fleet_ed25519'),
    [string]$ReportDir,
    [int]$ConnectTimeoutSec = 15,
    [int]$HealthDelaySec = 15,
    [switch]$DryRun,
    [switch]$FailOnWarn,
    [switch]$Quiet,
    [ValidateSet('accept-new', 'yes', 'no')]
    [string]$HostKeyPolicy = 'accept-new'
)

# Deliberately NOT setting $ErrorActionPreference = 'Stop': in PowerShell 5.1
# that turns native-command stderr (with 2>&1) into terminating errors.

# $PSScriptRoot can be empty inside a param() default under some PowerShell 5.1
# invocations (notably -File with a relative path), which made the Join-Path
# defaults throw "Cannot bind argument to parameter 'Path'". Resolve the script's
# own directory here - with a fallback - and fill in any path-based defaults the
# caller did not supply.
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition }
if (-not $ServerList) { $ServerList = Join-Path $ScriptDir 'servers.txt' }
if (-not $ReportDir) { $ReportDir = Join-Path $ScriptDir 'logs' }

function Write-Warn([string]$Message) {
    Write-Host ('WARNING: {0}' -f $Message) -ForegroundColor Yellow
}

function Fail-Preflight([string]$Message) {
    Write-Host ('ERROR: {0}' -f $Message) -ForegroundColor Red
    exit 2
}

# Locate ssh.exe; PATH first, then the standard Windows OpenSSH location
# (locked-down machines sometimes omit it from PATH).
function Resolve-SshExe {
    $cmd = Get-Command 'ssh.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return $null
}

# StrictHostKeyChecking=accept-new needs OpenSSH 7.6+ (every supported
# Windows 10/11 build ships 7.7+). Returns $true when the version is fine.
function Test-SshSupportsAcceptNew([string]$SshExe) {
    $verText = ''
    try { $verText = (& $SshExe -V 2>&1 | Out-String) } catch { $verText = '' }
    if ($verText -match 'OpenSSH_(\d+)\.(\d+)') {
        $major = [int]$Matches[1]
        $minor = [int]$Matches[2]
        if ($major -gt 7) { return $true }
        if (($major -eq 7) -and ($minor -ge 6)) { return $true }
        return $false
    }
    return $false
}

function Read-ServerList([string]$Path) {
    $servers = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($raw in @(Get-Content -LiteralPath $Path)) {
        $line = ('{0}' -f $raw).Trim()
        if ($line -eq '') { continue }
        if ($line.StartsWith('#')) { continue }
        # Hostname/IP only; anything else could smuggle extra ssh arguments.
        if ($line -notmatch '^[A-Za-z0-9.:_-]+$') {
            Write-Warn ('skipping invalid server entry: "{0}"' -f $line)
            continue
        }
        $key = $line.ToLowerInvariant()
        if ($seen.ContainsKey($key)) {
            Write-Warn ('duplicate server "{0}" - skipping repeat' -f $line)
            continue
        }
        $seen[$key] = $true
        [void]$servers.Add($line)
    }
    return , $servers
}

function Get-FirstLine([string]$Text) {
    if ($null -eq $Text) { return '' }
    foreach ($line in $Text -split "`r?`n") {
        $t = $line.Trim()
        if ($t -ne '') { return $t }
    }
    return ''
}

# With TreatControlCAsInput enabled, Ctrl+C lands in the console input buffer as
# an ordinary key event instead of stopping the script. Drain the buffer and
# report whether a Ctrl+C was among the pending keys.
function Test-CancelRequested {
    if (-not $script:CancelEnabled) { return $false }
    $found = $false
    try {
        while ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if (($key.Key -eq [ConsoleKey]::C) -and (($key.Modifiers -band [ConsoleModifiers]::Control) -ne 0)) {
                $found = $true
            }
        }
    }
    catch { }
    return $found
}

# Hand Ctrl+C back to the console (and clear any buffered keystrokes so they do
# not leak to the parent shell). Safe to call more than once.
function Restore-CtrlCMode {
    if (-not $script:CancelEnabled) { return }
    try {
        while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }
    }
    catch { }
    try { [Console]::TreatControlCAsInput = $false } catch { }
    $script:CancelEnabled = $false
}

# Run ssh via System.Diagnostics.Process: no cmd.exe quoting, no PowerShell
# re-encoding of the pipeline, and native stderr stays a plain string instead
# of becoming ErrorRecords.
function Invoke-SshPayload {
    param(
        [string]$SshExe,
        [string]$ArgumentString,
        [string]$PayloadText,
        [string]$Server,
        [bool]$ShowLive
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $SshExe
    $psi.Arguments = $ArgumentString
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding $false
    $psi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding $false

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    $stdoutLines = New-Object System.Collections.ArrayList
    $stderrText = ''
    $exitCode = -1

    try {
        [void]$proc.Start()

        # Drain stderr asynchronously so neither pipe can fill up and stall ssh.
        $errTask = $proc.StandardError.ReadToEndAsync()

        try {
            $proc.StandardInput.Write($PayloadText)
            $proc.StandardInput.Close()
        }
        catch {
            # ssh exited before consuming stdin (e.g. unreachable host);
            # the exit code and stderr tell the real story.
        }

        while ($null -ne ($line = $proc.StandardOutput.ReadLine())) {
            [void]$stdoutLines.Add($line)
            if ($ShowLive) { Write-Host ('[{0}] {1}' -f $Server, $line) }
        }

        $proc.WaitForExit()
        $exitCode = $proc.ExitCode
        $stderrText = $errTask.Result
    }
    finally {
        # HasExited itself throws if the process never started.
        try {
            if (-not $proc.HasExited) { $proc.Kill() }
        }
        catch { }
        $proc.Dispose()
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Stdout   = $stdoutLines
        Stderr   = $stderrText
    }
}

# Parse the PF|... marker lines out of the payload's stdout.
function ConvertFrom-Markers {
    param($Lines)

    $m = @{
        Begin       = $false
        End         = $false
        PayloadExit = ''
        Steps       = @{}
        Tags        = New-Object System.Collections.ArrayList
        Health      = New-Object System.Collections.ArrayList
        Info        = @{}
    }

    foreach ($raw in $Lines) {
        $t = ('{0}' -f $raw).Trim()
        if (-not $t.StartsWith('PF|')) { continue }
        $f = $t.Split('|')
        if ($f.Count -lt 2) { continue }
        switch ($f[1]) {
            'BEGIN' { $m.Begin = $true }
            'END' {
                $m.End = $true
                if ($f.Count -ge 3) { $m.PayloadExit = $f[2] }
            }
            'STEP' {
                if ($f.Count -ge 4) {
                    $rc = 0
                    if ([int]::TryParse($f[3], [ref]$rc)) { $m.Steps[$f[2]] = $rc }
                }
            }
            'TAG' {
                if ($f.Count -ge 3) { [void]$m.Tags.Add($f[2]) }
            }
            'HEALTH' {
                if ($f.Count -ge 4) { [void]$m.Health.Add(('{0} [{1}]' -f $f[2], $f[3])) }
            }
            'INFO' {
                if ($f.Count -ge 4) { $m.Info[$f[2]] = $f[3] }
            }
            default { }
        }
    }
    return $m
}

function Get-StepRc($Marks, [string]$Name) {
    if ($Marks.Steps.ContainsKey($Name)) { return $Marks.Steps[$Name] }
    return ''
}

function Get-InfoValue($Marks, [string]$Name) {
    if ($Marks.Info.ContainsKey($Name)) { return $Marks.Info[$Name] }
    return ''
}

# Decide OK / WARN / FAIL / UNREACHABLE for one server.
function Get-ServerStatus {
    param($Marks, [int]$SshExit, [string]$StderrText, [bool]$IsDryRun)

    if (-not $Marks.Begin) {
        if ($SshExit -eq 255) {
            $reason = Get-FirstLine $StderrText
            if ($reason -eq '') { $reason = 'ssh connection failed' }
            return [pscustomobject]@{ Status = 'UNREACHABLE'; Detail = $reason }
        }
        return [pscustomobject]@{ Status = 'FAIL'; Detail = ('no payload output (ssh exit code {0})' -f $SshExit) }
    }
    if (-not $Marks.End) {
        return [pscustomobject]@{ Status = 'FAIL'; Detail = 'connection lost mid-run (no END marker)' }
    }

    foreach ($step in @('repo', 'git_pull', 'build', 'update')) {
        $rc = Get-StepRc $Marks $step
        if (($rc -ne '') -and ($rc -ne 0)) {
            $note = ''
            if ($rc -eq 124) { $note = ' (timed out)' }
            return [pscustomobject]@{ Status = 'FAIL'; Detail = ("step '{0}' failed with rc {1}{2}" -f $step, $rc, $note) }
        }
    }
    if ((Get-StepRc $Marks 'health') -eq 1) {
        return [pscustomobject]@{ Status = 'FAIL'; Detail = 'no containers found (deployment absent or docker down)' }
    }

    $warns = @()
    if ($Marks.Tags.Count -gt 0) {
        $warns += ('{0} non-standard tag(s)' -f $Marks.Tags.Count)
    }
    $healthRc = Get-StepRc $Marks 'health'
    if (($healthRc -ne '') -and ($healthRc -ge 2)) {
        $warns += ('degraded: {0}' -f ($Marks.Health -join ', '))
    }
    $proxyRc = Get-StepRc $Marks 'proxy'
    if (($proxyRc -ne '') -and ($proxyRc -ne 0)) {
        $warns += 'proxy script missing or failed'
    }
    $fetchRc = Get-StepRc $Marks 'git_fetch'
    if (($fetchRc -ne '') -and ($fetchRc -ne 0)) {
        $warns += 'git fetch failed'
    }
    if ($IsDryRun) {
        $behind = Get-InfoValue $Marks 'behind'
        if (($behind -ne '') -and ($behind -ne '0') -and ($behind -ne 'unknown')) {
            $warns += ('{0} commit(s) behind origin' -f $behind)
        }
    }
    if ($warns.Count -gt 0) {
        return [pscustomobject]@{ Status = 'WARN'; Detail = ($warns -join '; ') }
    }

    $detail = 'ok'
    $before = Get-InfoValue $Marks 'commit_before'
    $after = Get-InfoValue $Marks 'commit_after'
    if ($IsDryRun) {
        $detail = 'reachable, up to date'
    }
    elseif (($before -ne '') -and ($after -ne '')) {
        if ($before -eq $after) { $detail = ('already on {0}' -f $after) }
        else { $detail = ('updated {0} -> {1}' -f $before, $after) }
    }
    return [pscustomobject]@{ Status = 'OK'; Detail = $detail }
}

# ---- preflight ---------------------------------------------------------------

$sshExe = Resolve-SshExe
if (-not $sshExe) {
    Fail-Preflight 'ssh.exe not found. The built-in Windows OpenSSH client is required (Windows 10 1809+ / Windows 11).'
}

if (-not (Test-SshSupportsAcceptNew $sshExe)) {
    if ($HostKeyPolicy -eq 'accept-new') {
        Write-Warn 'could not confirm this OpenSSH supports StrictHostKeyChecking=accept-new (needs 7.6+).'
        Write-Warn 'if connections fail with "Bad configuration option", rerun with -HostKeyPolicy yes'
        Write-Warn '(install-ssh-key.ps1 already added the host keys to known_hosts, so "yes" is safe).'
    }
}

if (-not (Test-Path -LiteralPath $ServerList)) {
    Fail-Preflight ('server list not found: {0} (copy servers.example.txt to servers.txt and edit it)' -f $ServerList)
}
if (-not (Test-Path -LiteralPath $KeyPath)) {
    Fail-Preflight ('ssh key not found: {0} (run install-ssh-key.ps1 first)' -f $KeyPath)
}
$payloadPath = Join-Path $ScriptDir 'update-server.sh'
if (-not (Test-Path -LiteralPath $payloadPath)) {
    Fail-Preflight ('payload not found: {0}' -f $payloadPath)
}

$servers = Read-ServerList $ServerList
if ($servers.Count -eq 0) {
    Fail-Preflight ('no servers found in {0}' -f $ServerList)
}

# The payload is ASCII; normalizing line endings here makes the run safe even
# if the file was checked out (or edited) with CRLF.
$payloadText = [System.IO.File]::ReadAllText($payloadPath)
$payloadText = $payloadText -replace "`r`n", "`n"
$payloadText = $payloadText -replace "`r", "`n"

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
}
catch { }

$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $ReportDir $runStamp
[void](New-Item -ItemType Directory -Path $runDir -Force)

# Ctrl+C handling: turn Ctrl+C into ordinary console input so it kills neither
# this script nor the in-flight ssh. We poll for it between servers (see the
# main loop) and stop gracefully, marking servers we never reached as SKIPPED.
$script:CancelEnabled = $false
$script:StopRequested = $false
try {
    [Console]::TreatControlCAsInput = $true
    $script:CancelEnabled = $true
}
catch {
    Write-Warn 'cannot capture Ctrl+C in this console; the run will not be interruptible.'
}

# Hand Ctrl+C back to the console even on an unexpected terminating error,
# otherwise the parent shell is left in raw-input mode.
trap {
    Restore-CtrlCMode
    break
}

$mode = 'update'
if ($DryRun) { $mode = 'check (dry run)' }
Write-Host ''
Write-Host ('Fleet {0}: {1} server(s) as {2}, logs in {3}' -f $mode, $servers.Count, $User, $runDir)
if ($script:CancelEnabled) {
    Write-Host '(Press Ctrl+C to stop gracefully after the current server.)' -ForegroundColor DarkGray
}
Write-Host ''

# ---- main loop ---------------------------------------------------------------

$results = New-Object System.Collections.ArrayList

foreach ($server in $servers) {
    if (-not $script:StopRequested -and (Test-CancelRequested)) {
        $script:StopRequested = $true
        Write-Host ''
        Write-Host 'Cancellation requested (Ctrl+C); skipping remaining servers.' -ForegroundColor Yellow
    }
    if ($script:StopRequested) {
        Write-Host ('--- {0}: SKIPPED (run cancelled)' -f $server) -ForegroundColor DarkYellow
        [void]$results.Add([pscustomobject]@{
                Server          = $server
                Status          = 'SKIPPED'
                Detail          = 'run cancelled before this server'
                Containers      = ''
                CommitBefore    = ''
                CommitAfter     = ''
                Behind          = ''
                ProjectName     = ''
                NonStandardTags = ''
                ContainersUp    = ''
                ContainersTotal = ''
                Proxy           = ''
                GitPull         = ''
                GitFetch        = ''
                Build           = ''
                TagScan         = ''
                Update          = ''
                Health          = ''
                PayloadExit     = ''
                SshExit         = ''
                DurationSec     = 0
                LogFile         = ''
            })
        continue
    }

    Write-Host ('>>> {0}' -f $server) -ForegroundColor Cyan
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $startedAt = Get-Date

    $remoteArgs = @('bash', '-s', '--')
    if ($DryRun) { $remoteArgs += '--check' }
    else { $remoteArgs += @('--health-delay', ('{0}' -f $HealthDelaySec)) }

    $keyArg = $KeyPath
    if ($keyArg -match '\s') { $keyArg = ('"{0}"' -f $keyArg) }
    $sshArgs = @(
        '-i', $keyArg,
        '-o', 'IdentitiesOnly=yes',
        '-o', 'BatchMode=yes',
        '-o', ('ConnectTimeout={0}' -f $ConnectTimeoutSec),
        '-o', ('StrictHostKeyChecking={0}' -f $HostKeyPolicy),
        '-o', 'ServerAliveInterval=15',
        '-o', 'ServerAliveCountMax=3',
        '-T',
        ('{0}@{1}' -f $User, $server)
    ) + $remoteArgs

    $sshExit = -1
    $stdout = @()
    $stderrText = ''
    $marks = ConvertFrom-Markers @()
    $verdict = $null

    try {
        $run = Invoke-SshPayload -SshExe $sshExe -ArgumentString ($sshArgs -join ' ') `
            -PayloadText $payloadText -Server $server -ShowLive (-not $Quiet)
        $sshExit = $run.ExitCode
        $stdout = $run.Stdout
        $stderrText = $run.Stderr
        $marks = ConvertFrom-Markers $stdout
        $verdict = Get-ServerStatus -Marks $marks -SshExit $sshExit -StderrText $stderrText -IsDryRun ([bool]$DryRun)
    }
    catch {
        $verdict = [pscustomobject]@{ Status = 'FAIL'; Detail = ('orchestrator error: {0}' -f $_.Exception.Message) }
    }

    $watch.Stop()

    # Per-server log file.
    $safeName = ($server -replace '[^A-Za-z0-9._-]', '_')
    $logFile = Join-Path $runDir ('{0}.log' -f $safeName)
    $logParts = New-Object System.Collections.ArrayList
    [void]$logParts.Add(('server   : {0}' -f $server))
    [void]$logParts.Add(('started  : {0}' -f $startedAt.ToString('yyyy-MM-dd HH:mm:ss')))
    [void]$logParts.Add(('duration : {0}s' -f [int]$watch.Elapsed.TotalSeconds))
    [void]$logParts.Add(('ssh exit : {0}' -f $sshExit))
    [void]$logParts.Add(('status   : {0} - {1}' -f $verdict.Status, $verdict.Detail))
    [void]$logParts.Add('')
    [void]$logParts.Add('--- remote output ---')
    foreach ($line in $stdout) { [void]$logParts.Add($line) }
    [void]$logParts.Add('')
    [void]$logParts.Add('--- ssh stderr ---')
    [void]$logParts.Add(('{0}' -f $stderrText))
    ($logParts -join [Environment]::NewLine) | Out-File -FilePath $logFile -Encoding utf8

    $containersUp = Get-InfoValue $marks 'containers_up'
    $containersTotal = Get-InfoValue $marks 'containers_total'
    $containers = ''
    if ($containersTotal -ne '') { $containers = ('{0}/{1}' -f $containersUp, $containersTotal) }

    $result = [pscustomobject]@{
        Server          = $server
        Status          = $verdict.Status
        Detail          = $verdict.Detail
        Containers      = $containers
        CommitBefore    = Get-InfoValue $marks 'commit_before'
        CommitAfter     = Get-InfoValue $marks 'commit_after'
        Behind          = Get-InfoValue $marks 'behind'
        ProjectName     = Get-InfoValue $marks 'project_name'
        NonStandardTags = ($marks.Tags -join '; ')
        ContainersUp    = $containersUp
        ContainersTotal = $containersTotal
        Proxy           = Get-StepRc $marks 'proxy'
        GitPull         = Get-StepRc $marks 'git_pull'
        GitFetch        = Get-StepRc $marks 'git_fetch'
        Build           = Get-StepRc $marks 'build'
        TagScan         = Get-StepRc $marks 'tag_scan'
        Update          = Get-StepRc $marks 'update'
        Health          = Get-StepRc $marks 'health'
        PayloadExit     = $marks.PayloadExit
        SshExit         = $sshExit
        DurationSec     = [int]$watch.Elapsed.TotalSeconds
        LogFile         = $logFile
    }
    [void]$results.Add($result)

    $color = 'Green'
    if ($verdict.Status -eq 'WARN') { $color = 'Yellow' }
    if (($verdict.Status -eq 'FAIL') -or ($verdict.Status -eq 'UNREACHABLE')) { $color = 'Red' }
    Write-Host ('<<< {0}: {1} - {2}' -f $server, $verdict.Status, $verdict.Detail) -ForegroundColor $color
    Write-Host ''
}

# ---- summary -----------------------------------------------------------------

$csvPath = Join-Path $runDir 'summary.csv'
$results |
    Select-Object Server, Status, Detail, CommitBefore, CommitAfter, Behind, ProjectName,
        NonStandardTags, ContainersUp, ContainersTotal, Proxy, GitPull, GitFetch, Build,
        TagScan, Update, Health, PayloadExit, SshExit, DurationSec, LogFile |
    Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host '==================== SUMMARY ====================' -ForegroundColor Cyan
$results |
    Select-Object Server, Status, Containers, @{ Name = 'Tags'; Expression = { $_.NonStandardTags } }, DurationSec, Detail |
    Format-Table -AutoSize -Wrap |
    Out-Host

$okCount = @($results | Where-Object { $_.Status -eq 'OK' }).Count
$warnCount = @($results | Where-Object { $_.Status -eq 'WARN' }).Count
$failCount = @($results | Where-Object { ($_.Status -eq 'FAIL') -or ($_.Status -eq 'UNREACHABLE') }).Count
$skipCount = @($results | Where-Object { $_.Status -eq 'SKIPPED' }).Count
if ($script:StopRequested) {
    Write-Host ''
    Write-Host ('Run cancelled (Ctrl+C): {0} server(s) skipped.' -f $skipCount) -ForegroundColor Yellow
}
Write-Host ('Total: {0}  OK: {1}  WARN: {2}  FAIL/UNREACHABLE: {3}  SKIPPED: {4}' -f $results.Count, $okCount, $warnCount, $failCount, $skipCount)
Write-Host ('Logs and summary.csv: {0}' -f $runDir)

$badCount = $failCount
if ($FailOnWarn) { $badCount = $failCount + $warnCount }
Restore-CtrlCMode
if ($badCount -gt 0) { exit 1 }
exit 0
