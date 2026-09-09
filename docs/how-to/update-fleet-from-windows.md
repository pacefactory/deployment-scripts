---
title: "Update the fleet from Windows"
type: how-to
derived_from:
  - scripts/remote/update-fleet.ps1
  - scripts/remote/install-ssh-key.ps1
  - scripts/remote/update-server.sh
  - scripts/remote/servers.example.txt
  - .gitattributes
last_verified: 2026-09-09
verified_against: ccf3768
---

# Update the fleet from Windows

## Goal

Run `git pull`, `build.sh -q` and `update.sh -q` on many deployment servers
from a Windows machine over ssh, with a health check and a summary report.

## Prerequisites

- [ ] Windows 10 1809+ / 11 with the built-in OpenSSH client (`ssh -V` in PowerShell) and PowerShell 5.1+. No admin rights or third-party software needed.
- [ ] The `pacefactory` account password for each server (once, for key installation).
- [ ] Each server set up the usual way: repo at `~/scv2/git_clones/deployment-scripts`, `~/connect-to-proxy.sh` present where a proxy is needed, Docker Hub credentials stored for the account.
- [ ] `scripts/remote/servers.txt`: one hostname or IP per line, copied from `servers.example.txt` (gitignored).
- [ ] If script execution is blocked: run with `powershell.exe -ExecutionPolicy Bypass -File …`. A GPO enforcing `AllSigned` defeats this; talk to IT.

## Steps

1. One-time key installation. For each server confirm the host key and enter
   the password once; the script verifies key auth and skips servers already
   set up:

   ```powershell
   cd scripts\remote
   powershell.exe -ExecutionPolicy Bypass -File .\install-ssh-key.ps1
   ```

   The key is a dedicated passphrase-less ed25519 key for the `pacefactory`
   account only (default `%USERPROFILE%\.ssh\pf_fleet_ed25519`). Do not reuse
   it; revoke by deleting its line from `~/.ssh/authorized_keys` on the servers.

2. Read-only preflight (reachability, commits behind origin, current tags,
   health; changes nothing):

   ```powershell
   .\update-fleet.ps1 -DryRun
   ```

3. Update every server in `servers.txt`, sequentially:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\update-fleet.ps1
   ```

   Options: `-ServerList <FILE>` (any list file), `-FailOnWarn` (non-standard
   tags or degraded containers count as failures), `-Quiet`,
   `-HealthDelaySec <N>` (default 15; raise for slow sites),
   `-HostKeyPolicy yes` for very old OpenSSH clients that reject `accept-new`.

   On each server the streamed payload (`update-server.sh`) does:
   `source ~/connect-to-proxy.sh` (warning if missing) → `cd` to the repo →
   `git pull --ff-only` → `./build.sh -q` and validate `docker-compose.yml` →
   scan for `pacefactory/*` images not on `latest`/`latest-gpu` (reported as
   `WARN`, not blocking; pins live per server in `.env` on purpose) →
   `./update.sh -q` (must print "Deployment complete") → after the settle delay,
   check every container is `Up` and not `(unhealthy)`.

   Ctrl+C stops gracefully: the server in progress finishes, the rest are
   `SKIPPED`, the summary is still written.

## Verify

Each run writes `scripts\remote\logs\<timestamp>\` with `<server>.log` and
`summary.csv` (status, commits before/after, non-standard tags, container
counts, per-step exit codes).

| Status | Meaning |
|---|---|
| `OK` | Updated; all containers up |
| `WARN` | Updated but needs attention: non-standard tags, degraded containers, or missing proxy script |
| `FAIL` | A step failed; see Detail and the server log |
| `UNREACHABLE` | ssh could not connect |
| `SKIPPED` | Not attempted (Ctrl+C) |

Script exit code: `0` all OK/WARN, `1` any FAIL/UNREACHABLE (and WARN with
`-FailOnWarn`), `2` usage or preflight error. Payload exit codes: `11` repo
dir missing, `12` git pull failed, `13` build failed or invalid compose file,
`14` update.sh failed, `15` no containers, `16` degraded containers; a step rc
of `124` is a timeout (pull 10 min, build 15 min, update 60 min). The payload
does not trust `build.sh`/`update.sh` exit codes, which can be 0 on failure.

Troubleshooting: `UNREACHABLE` → VPN/DNS and a manual
`ssh pacefactory@<SERVER>`; `REMOTE HOST IDENTIFICATION HAS CHANGED` → confirm
why, remove the line from `%USERPROFILE%\.ssh\known_hosts`, re-run the
installer; key auth failing after install → re-run the installer (applies
`restorecon` for the usual RHEL/SELinux label problem) and check
`chmod go-w ~ ~/.ssh` on the server; `git pull --ff-only` fails on purpose
when a server's clone has diverged, fix it by hand there.

## Rollback

Per server: pin the previous tags in `.env`, `./build.sh -q`, `./update.sh -q`.

## Related

- [Fleet SSH integration](../architecture/integrations/fleet-ssh.md)
- [Update a deployment](update-a-deployment.md)
