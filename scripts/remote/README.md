# Remote fleet updates (from Windows)

Semi-automated `git pull` + `build.sh` + `update.sh` across a fleet of
deployment servers, run from a Windows machine over ssh.

Designed for locked-down environments: it only needs the **built-in Windows
OpenSSH client** and PowerShell 5.1+ — no admin rights, no third-party
software.

| File | Purpose |
| --- | --- |
| `install-ssh-key.ps1` | One-time setup: create a key and install it on every server |
| `update-fleet.ps1` | Routine use: run the update payload on every server, report results |
| `update-server.sh` | The payload that runs on each server (streamed over ssh, never copied) |
| `servers.example.txt` | Template for your server list |

## Prerequisites

- Windows 10 1809+ / Windows 11 with the OpenSSH client (check with `ssh -V`
  in PowerShell — it ships enabled by default).
- PowerShell 5.1+ (the Windows default is fine).
- The `pacefactory` account password for each server (needed once, during
  key installation).
- Each server already set up the usual way: repo cloned at
  `~/scv2/git_clones/deployment-scripts`, `~/connect-to-proxy.sh` present
  (optional), docker registry credentials already stored for the account.

If script execution is blocked on your machine, run the scripts as:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\update-fleet.ps1
```

(If a GPO enforces `AllSigned`, that bypass won't work — talk to IT.)

## One-time setup

1. Get this repo onto the Windows machine (clone it, or copy this folder).
2. In this folder, copy `servers.example.txt` to `servers.txt` and put one
   hostname/IP per line. `servers.txt` is gitignored — it never gets
   committed.
3. Run the key installer and follow the prompts:

   ```powershell
   cd scripts\remote
   powershell.exe -ExecutionPolicy Bypass -File .\install-ssh-key.ps1
   ```

   For each server you'll be asked to confirm the host key (type `yes`) and
   enter the password **once**. The script then verifies key-based auth
   actually works. Re-running it is always safe; it skips servers that are
   already set up.

## Routine use

```powershell
# Update every server in servers.txt:
powershell.exe -ExecutionPolicy Bypass -File .\update-fleet.ps1

# Read-only preflight: reachability, commits behind origin, current tags, health:
.\update-fleet.ps1 -DryRun

# Just one server (any alternate list file works):
.\update-fleet.ps1 -ServerList .\just-one.txt

# Treat warnings (non-standard tags, degraded containers) as failures:
.\update-fleet.ps1 -FailOnWarn

# Less console noise, slower services need longer before the health check:
.\update-fleet.ps1 -Quiet -HealthDelaySec 60
```

Servers are processed **sequentially**, and a failure on one server never
stops the rest of the run.

Press **Ctrl+C** to stop gracefully: the server currently being updated
finishes (so it is never left half-migrated), the servers not yet reached are
marked `SKIPPED`, and the summary and per-server logs are still written. Note
that Ctrl+C does *not* abort the server in progress — if it is mid-pull on a
large image, it runs to completion before the run stops.

## What a run does on each server

1. `source ~/connect-to-proxy.sh` (warning if missing, not fatal)
2. `cd ~/scv2/git_clones/deployment-scripts`
3. `git pull --ff-only`
4. `./build.sh -q` (then validates the generated `docker-compose.yml`)
5. Scan the resolved compose file for **pacefactory images whose tag is not
   `latest`/`latest-gpu`** — e.g. a service pinned to `:1.4.2` for a site.
   These are *reported, not blocking*: the run continues and the server shows
   up as `WARN`. To clear one, fix the pinned `*_TAG` value in the server's
   `.env` (or re-run `./build.sh` there) — pins live per-server, on purpose.
6. `./update.sh -q` (pull images + relaunch)
7. After a short settle delay (`-HealthDelaySec`, default 15s), check that
   every container of the compose project is `Up` and not `(unhealthy)`.

`-DryRun` replaces 3–6 with `git fetch` + "commits behind origin" and checks
current state only — nothing on the server is modified.

## Reading the output

Each run writes `logs\<timestamp>\`:

- `<server>.log` — full remote output plus ssh transport errors per server
- `summary.csv` — one row per server (status, commits before/after,
  non-standard tags, container counts, per-step exit codes, log path)

Statuses:

| Status | Meaning |
| --- | --- |
| `OK` | Updated; all containers up |
| `WARN` | Updated, but needs attention: non-standard tags, degraded containers, or missing proxy script |
| `FAIL` | A step failed — see Detail and the server's log file |
| `UNREACHABLE` | ssh could not connect (DNS, network, auth) |
| `SKIPPED` | Not attempted; the run was cancelled with Ctrl+C |

Script exit code: `0` all OK/WARN, `1` any FAIL/UNREACHABLE (and WARN too
with `-FailOnWarn`), `2` usage/preflight error.

Payload exit codes (the `PayloadExit` CSV column): `11` repo dir missing,
`12` git pull failed, `13` build failed or produced an invalid compose file,
`14` update.sh failed, `15` no containers found, `16` degraded containers.
A step rc of `124` means that step hit its timeout (pull 10 min, build
15 min, update 60 min).

The payload prints machine-readable `PF|...` marker lines (BEGIN/STEP/TAG/
HEALTH/INFO/END) between the normal command output; the orchestrator parses
those, and they make the raw logs easy to skim too.

### Why FAIL can appear even when scripts "succeeded"

`update.sh`/`build.sh` can exit 0 even when a pull or compose generation
failed, so the payload doesn't trust exit codes alone: it validates the
generated `docker-compose.yml`, requires update.sh's "Deployment complete"
message, and independently checks containers via `docker ps`.

## Caveats

- The health check is a **snapshot** taken ~15s after `up`: a container that
  crash-loops later can be missed, and a slow starter can show up as
  transiently degraded. Treat `WARN` as "go look", and bump
  `-HealthDelaySec` for slow sites.
- `git pull --ff-only` fails on purpose if a server's clone has diverged
  (local commits). Fix that server by hand (`git status` there), then re-run.

## Troubleshooting

- **UNREACHABLE**: check VPN/network, DNS, and that you can
  `ssh pacefactory@<server>` manually from the same machine.
- **`REMOTE HOST IDENTIFICATION HAS CHANGED`**: the server was reinstalled
  (or something worse). After confirming why, remove the old line from
  `%USERPROFILE%\.ssh\known_hosts` and re-run `install-ssh-key.ps1`.
- **Key auth still fails after install**: re-run `install-ssh-key.ps1` (it
  applies `restorecon`, which fixes the usual RHEL/SELinux label problem).
  Also check on the server that the home directory is not group/other
  writable: `chmod go-w ~ ~/.ssh`.
- **`Bad configuration option: accept-new`**: very old OpenSSH client;
  re-run with `-HostKeyPolicy yes` (safe because the installer already put
  the servers in `known_hosts`).
- **Proxy warnings**: the payload continues without
  `~/connect-to-proxy.sh`; if git/docker then fail on that server, the proxy
  script is missing where it is actually needed.

## Security notes

- The key is a dedicated, passphrase-less ed25519 key for the `pacefactory`
  account only (default `%USERPROFILE%\.ssh\pf_fleet_ed25519`). Don't reuse
  it for anything else; revoke it by deleting its line from
  `~/.ssh/authorized_keys` on the servers.
- `servers.txt` and `logs/` are gitignored: real hostnames and run output
  never get committed.
