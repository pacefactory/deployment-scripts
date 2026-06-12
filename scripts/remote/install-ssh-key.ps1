<#
.SYNOPSIS
    One-time setup for the fleet update tooling: creates a dedicated ssh key
    (if needed) and installs it on every server in the list.

.DESCRIPTION
    For each server in the list (default: servers.txt next to this script):

      1. Probes whether key-based auth already works (skipped with -Force).
      2. If not, connects interactively - you will be asked to confirm the
         host key on first contact (type 'yes') and to enter the account
         password ONCE - and appends the public key to ~/.ssh/authorized_keys
         with correct permissions. On SELinux hosts (RHEL) it also runs
         restorecon, which fixes the classic "key auth silently ignored"
         problem.
      3. Re-probes to verify key-based auth now works.

    The interactive connection also records each server in known_hosts, so
    later update-fleet.ps1 runs never see a host-key prompt.

    Only the built-in Windows OpenSSH client is required (no admin rights).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install-ssh-key.ps1

.EXAMPLE
    .\install-ssh-key.ps1 -ServerList .\new-servers.txt

.NOTES
    Exit codes: 0 = key works on every server, 1 = at least one failure,
    2 = preflight error.
#>
[CmdletBinding()]
param(
    [string]$ServerList = (Join-Path $PSScriptRoot 'servers.txt'),
    [string]$User = 'pacefactory',
    [string]$KeyPath = (Join-Path $env:USERPROFILE '.ssh\pf_fleet_ed25519'),
    [switch]$Force
)

# Deliberately NOT setting $ErrorActionPreference = 'Stop': in PowerShell 5.1
# that turns native-command stderr (with 2>&1) into terminating errors.

function Write-Warn([string]$Message) {
    Write-Host ('WARNING: {0}' -f $Message) -ForegroundColor Yellow
}

function Fail-Preflight([string]$Message) {
    Write-Host ('ERROR: {0}' -f $Message) -ForegroundColor Red
    exit 2
}

function Resolve-OpenSshTool([string]$Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = Join-Path $env:WINDIR ('System32\OpenSSH\{0}' -f $Name)
    if (Test-Path -LiteralPath $fallback) { return $fallback }
    return $null
}

function Read-ServerList([string]$Path) {
    $servers = New-Object System.Collections.ArrayList
    $seen = @{}
    foreach ($raw in @(Get-Content -LiteralPath $Path)) {
        $line = ('{0}' -f $raw).Trim()
        if ($line -eq '') { continue }
        if ($line.StartsWith('#')) { continue }
        if ($line -notmatch '^[A-Za-z0-9.:_-]+$') {
            Write-Warn ('skipping invalid server entry: "{0}"' -f $line)
            continue
        }
        $key = $line.ToLowerInvariant()
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        [void]$servers.Add($line)
    }
    return , $servers
}

# Non-interactive probe: does key-based auth work right now?
function Test-KeyAuth([string]$SshExe, [string]$Key, [string]$Target) {
    $out = ''
    try {
        $out = (& $SshExe -i $Key -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 $Target 'echo PF_KEY_OK' 2>&1 | Out-String)
    }
    catch {
        return $false
    }
    if ($LASTEXITCODE -ne 0) { return $false }
    return ($out -match 'PF_KEY_OK')
}

# ---- preflight ---------------------------------------------------------------

$sshExe = Resolve-OpenSshTool 'ssh.exe'
$sshKeygenExe = Resolve-OpenSshTool 'ssh-keygen.exe'
if (-not $sshExe) {
    Fail-Preflight 'ssh.exe not found. The built-in Windows OpenSSH client is required (Windows 10 1809+ / Windows 11).'
}
if (-not $sshKeygenExe) {
    Fail-Preflight 'ssh-keygen.exe not found (it ships with the built-in Windows OpenSSH client).'
}
if (-not (Test-Path -LiteralPath $ServerList)) {
    Fail-Preflight ('server list not found: {0} (copy servers.example.txt to servers.txt and edit it)' -f $ServerList)
}

$servers = Read-ServerList $ServerList
if ($servers.Count -eq 0) {
    Fail-Preflight ('no servers found in {0}' -f $ServerList)
}

# ---- key generation (idempotent) ----------------------------------------------

if (Test-Path -LiteralPath $KeyPath) {
    Write-Host ('Using existing key: {0}' -f $KeyPath)
}
else {
    $keyDir = Split-Path -Parent $KeyPath
    if (($keyDir -ne '') -and (-not (Test-Path -LiteralPath $keyDir))) {
        [void](New-Item -ItemType Directory -Path $keyDir -Force)
    }
    $comment = ('pf-fleet-{0}@{1}' -f $env:USERNAME, $env:COMPUTERNAME)
    Write-Host ('Generating new ed25519 key: {0}' -f $KeyPath)
    # '""' is how PowerShell 5.1 passes an empty -N (no passphrase) argument.
    & $sshKeygenExe -t ed25519 -f $KeyPath -N '""' -C $comment
    if (-not (Test-Path -LiteralPath $KeyPath)) {
        Write-Warn 'ssh-keygen did not accept the empty passphrase argument; retrying interactively.'
        Write-Host 'When asked for a passphrase, press Enter twice to leave it empty.'
        & $sshKeygenExe -t ed25519 -f $KeyPath -C $comment
    }
    if (-not (Test-Path -LiteralPath $KeyPath)) {
        Fail-Preflight 'key generation failed'
    }
}

$pubKeyPath = ('{0}.pub' -f $KeyPath)
if (-not (Test-Path -LiteralPath $pubKeyPath)) {
    Fail-Preflight ('public key not found: {0}' -f $pubKeyPath)
}
$pubKey = ([System.IO.File]::ReadAllText($pubKeyPath)).Trim()

# The key is embedded between single quotes in a remote shell command, so be
# strict about what it may contain.
if ($pubKey -notmatch '^ssh-ed25519 [A-Za-z0-9+/=]+( [A-Za-z0-9@._-]+)?$') {
    Fail-Preflight ('unexpected public key format in {0}' -f $pubKeyPath)
}

Write-Host 'Key fingerprint:'
& $sshKeygenExe -lf $pubKeyPath
Write-Host ''

# Appends the key (exact-line dedupe, so re-runs are harmless), fixes
# permissions, and restores SELinux labels where applicable.
$remoteCmd = (@(
        'umask 077',
        'mkdir -p ~/.ssh',
        'chmod 700 ~/.ssh',
        'touch ~/.ssh/authorized_keys',
        'chmod 600 ~/.ssh/authorized_keys',
        ("grep -qxF '{0}' ~/.ssh/authorized_keys || printf '%s\n' '{0}' >> ~/.ssh/authorized_keys" -f $pubKey),
        'if command -v restorecon >/dev/null 2>&1; then restorecon -R ~/.ssh; fi',
        'echo PF_KEY_INSTALLED'
    ) -join '; ')

# ---- per-server install --------------------------------------------------------

$results = New-Object System.Collections.ArrayList

foreach ($server in $servers) {
    $target = ('{0}@{1}' -f $User, $server)
    Write-Host ('>>> {0}' -f $target) -ForegroundColor Cyan

    if ((-not $Force) -and (Test-KeyAuth $sshExe $KeyPath $target)) {
        Write-Host '    key auth already works, skipping'
        [void]$results.Add([pscustomobject]@{ Server = $server; Status = 'AlreadyInstalled'; Detail = '' })
        continue
    }

    Write-Host ('    Connecting interactively. If asked about the host key, type "yes".')
    Write-Host ('    Then enter the password for {0} (this is the only time it is needed).' -f $target)

    # Interactive on purpose: ssh reads the host-key answer and password from
    # the console. The key is offered first, password is the fallback.
    & $sshExe -i $KeyPath -o IdentitiesOnly=yes -o ConnectTimeout=15 $target $remoteCmd
    $installExit = $LASTEXITCODE
    if ($installExit -ne 0) {
        Write-Warn ('install command failed (ssh exit {0})' -f $installExit)
        [void]$results.Add([pscustomobject]@{ Server = $server; Status = 'Failed'; Detail = ('install ssh exit {0}' -f $installExit) })
        continue
    }

    if (Test-KeyAuth $sshExe $KeyPath $target) {
        Write-Host '    verified: key auth works' -ForegroundColor Green
        [void]$results.Add([pscustomobject]@{ Server = $server; Status = 'Installed'; Detail = '' })
    }
    else {
        Write-Warn 'key was installed but key-based auth still fails'
        [void]$results.Add([pscustomobject]@{
                Server = $server
                Status = 'Failed'
                Detail = 'verification probe failed; check home dir permissions on the server (no group/other write) and sshd_config AuthorizedKeysFile'
            })
    }
}

# ---- summary -------------------------------------------------------------------

Write-Host ''
$results | Format-Table -AutoSize -Wrap | Out-Host

$failed = @($results | Where-Object { $_.Status -eq 'Failed' }).Count
if ($failed -gt 0) {
    Write-Host ('{0} server(s) failed - fix and re-run (re-runs are safe).' -f $failed) -ForegroundColor Red
    exit 1
}
Write-Host 'All servers ready. You can now run update-fleet.ps1.' -ForegroundColor Green
exit 0
