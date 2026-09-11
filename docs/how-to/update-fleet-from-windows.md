---
title: "Update the fleet from Windows"
type: how-to
derived_from:
  - scripts/remote/update-fleet.ps1
  - scripts/remote/install-ssh-key.ps1
  - scripts/remote/update-server.sh
  - scripts/remote/servers.example.txt
  - scripts/release/fetch-release.sh
  - .gitattributes
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Update the fleet from Windows

## Goal

Run the release fetch, `build.sh -q` and `update.sh -q` on many deployment
servers from a Windows machine over ssh, with a health check and a summary
report that also shows which servers have not been migrated to the release
image yet.

## Prerequisites

- [ ] Windows 10 1809+ / 11 with the built-in OpenSSH client (`ssh -V` in PowerShell) and PowerShell 5.1+. No admin rights or third-party software needed.
- [ ] The `pacefactory` account password for each server (once, for key installation).
- [ ] Each server set up the usual way: deployment-scripts installed from the release image at `~/scv2/git_clones/deployment-scripts` ([Install or repair deployment-scripts on a server](install-deployment-scripts.md)), `~/connect-to-proxy.sh` present where a proxy is needed, the server's Docker Hub token in `~/scv2/docker_oat.sh` and a standing login as `pacefactory` (`scripts/common/dockerLogin.sh:5-13`; issuance is in the Pacefactory Deployment Guide, `TODO(source)`). A server still on the old `git clone` is reported as `NOT MIGRATED` and is not updated (`scripts/remote/update-server.sh:49-50,140-145`).
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

2. Read-only preflight (reachability, installed release and whether a newer
   one is published, migration state, current tags, health; changes nothing):

   ```powershell
   .\update-fleet.ps1 -DryRun
   ```

   The payload runs `scripts/release/fetch-release.sh --check` on each
   server (`scripts/remote/update-server.sh:153-167`). A server with a newer
   release available, a blocked conversion or no release install shows as
   `WARN` with the reason.

3. Update every server in `servers.txt`, sequentially:

   ```powershell
   powershell.exe -ExecutionPolicy Bypass -File .\update-fleet.ps1
   ```

   Options: `-ServerList <FILE>` (any list file), `-FailOnWarn` (non-standard
   tags or degraded containers count as failures), `-Quiet`,
   `-HealthDelaySec <N>` (default 15; raise for slow sites),
   `-HostKeyPolicy yes` for very old OpenSSH clients that reject `accept-new`.

   On each server the streamed payload (`update-server.sh`) does:
   `source ~/connect-to-proxy.sh` (warning if missing) → `cd` to the install
   directory → `scripts/release/fetch-release.sh` (pull the release image,
   sync the tree by manifest; `scripts/remote/update-server.sh:140-150`) →
   `./build.sh -q` and validate `docker-compose.yml` → scan for
   `pacefactory/*` images not on `latest`/`latest-gpu` (reported as `WARN`,
   not blocking; pins live per server in `.env` on purpose) →
   `./update.sh -q` (must print "Deployment complete") → after the settle
   delay, check every container is `Up` and not `(unhealthy)`.

   Ctrl+C stops gracefully: the server in progress finishes, the rest are
   `SKIPPED`, the summary is still written.

## Verify

Each run writes `scripts\remote\logs\<timestamp>\` with `<server>.log` and
`summary.csv` (status, marker protocol version, migration state, release
before/after, whether an update is available, non-standard tags, container
counts, per-step exit codes). The console table has a `Release` column: the
installed release, `NOT MIGRATED`, or `git <commit> (v1 payload)` for a
server answering with the old marker protocol.

| Status | Meaning |
|---|---|
| `OK` | Updated; all containers up |
| `WARN` | Updated but needs attention: non-standard tags, degraded containers, missing proxy script; in `-DryRun` also a release update available, a conversion blocked by modified tracked files, or `NOT MIGRATED` |
| `FAIL` | A step failed; see Detail and the server log. `NOT MIGRATED` in update mode: convert the server with the install one-liner, then re-run |
| `UNREACHABLE` | ssh could not connect |
| `SKIPPED` | Not attempted (Ctrl+C) |

Script exit code: `0` all OK/WARN, `1` any FAIL/UNREACHABLE (and WARN with
`-FailOnWarn`), `2` usage or preflight error. Payload exit codes
(`scripts/remote/update-server.sh:41-55`): `11` install directory missing,
`12` release fetch failed (pull, extract, sync, or conversion refused), `13`
build failed or invalid compose file, `14` update.sh failed, `15` no
containers, `16` degraded containers, `17` server not migrated; a step rc of
`124` is a timeout (fetch 10 min, check 5 min, build 15 min, update 60 min).
The payload does not trust `build.sh`/`update.sh` exit codes, which can be 0
on failure. Markers start with `PF|BEGIN|v2`; v1 markers are still parsed and
labelled.

Troubleshooting: `UNREACHABLE` → VPN/DNS and a manual
`ssh pacefactory@<SERVER>`; `REMOTE HOST IDENTIFICATION HAS CHANGED` → confirm
why, remove the line from `%USERPROFILE%\.ssh\known_hosts`, re-run the
installer; key auth failing after install → re-run the installer (applies
`restorecon` for the usual RHEL/SELinux label problem) and check
`chmod go-w ~ ~/.ssh` on the server; `NOT MIGRATED` → run
`curl -fsSL https://get.pacefactory.dev/install.sh | bash` on that server as
`pacefactory`; fetch rc `4` → the checkout has modified tracked files, fix them
by hand there; fetch fails with a pull error → the server's Docker Hub token
may be revoked, see [Install or repair](install-deployment-scripts.md#troubleshooting).

## Rollback

Per server: pin the previous image tags in `.env`, `./build.sh -q`,
`./update.sh -q`. Scripts tree: `PF_RELEASE=<TAG> ./scripts/release/fetch-release.sh`
on the server ([Install or repair](install-deployment-scripts.md#rollback)).

## Related

- [Fleet SSH integration](../architecture/integrations/fleet-ssh.md)
- [Update a deployment](update-a-deployment.md)
- [Install or repair deployment-scripts on a server](install-deployment-scripts.md)
