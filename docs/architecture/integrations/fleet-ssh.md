---
title: "Fleet operator workstation (SSH)"
type: reference
derived_from:
  - scripts/remote/update-fleet.ps1
  - scripts/remote/install-ssh-key.ps1
  - scripts/remote/update-server.sh
  - .gitattributes
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Fleet operator workstation (SSH)

## What it connects to

A Pacefactory operator's Windows workstation running `scripts/remote/` to
update many deployment hosts.

## Which Pacefactory services participate, and via which profile(s)

No compose service. The host's `pacefactory` account receives an ssh session
that streams `scripts/remote/update-server.sh` to `bash -s`
(`scripts/remote/update-server.sh:9-15`). The payload runs
`scripts/release/fetch-release.sh` (the release image fetch that replaced
`git pull`, `scripts/remote/update-server.sh:140-150`), `./build.sh -q`,
`./update.sh -q` and a container health check in
`~/scv2/git_clones/deployment-scripts`, and reports markers in protocol v2
(`scripts/remote/update-server.sh:21-39`).

## Direction and protocol(s)

Inbound SSH (22) to the host, key-based (`ed25519` key installed by
`install-ssh-key.ps1`, default `%USERPROFILE%\.ssh\pf_fleet_ed25519`, user
`pacefactory`). Shell scripts are LF-only for this reason (`.gitattributes`).

## Client-side network requirements

SSH from the operator network (or VPN) to every deployment host. See
[site requirements](../network/site-requirements.md) and
[Update the fleet from Windows](../../how-to/update-fleet-from-windows.md).

## Payload summary

Shell script over stdin; `PF|...` marker lines back over stdout, including the
installed release before and after and whether the server is migrated.

## Failure modes at the boundary

`UNREACHABLE` per server in the summary; a failure on one server never stops
the run (`scripts/remote/README.md` behaviour, now in the how-to).

## Variants

None.
