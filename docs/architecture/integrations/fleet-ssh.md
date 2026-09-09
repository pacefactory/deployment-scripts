---
title: "Fleet operator workstation (SSH)"
type: reference
derived_from:
  - scripts/remote/update-fleet.ps1
  - scripts/remote/install-ssh-key.ps1
  - scripts/remote/update-server.sh
  - .gitattributes
last_verified: 2026-09-09
verified_against: ccf3768
---

# Fleet operator workstation (SSH)

## What it connects to

A Pacefactory operator's Windows workstation running `scripts/remote/` to
update many deployment hosts.

## Which Pacefactory services participate, and via which profile(s)

No compose service. The host's `pacefactory` account receives an ssh session
that streams `scripts/remote/update-server.sh` to `bash -s`
(`scripts/remote/update-server.sh:5-7`). The payload runs `git pull`,
`./build.sh -q`, `./update.sh -q` and a container health check in
`~/scv2/git_clones/deployment-scripts`.

## Direction and protocol(s)

Inbound SSH (22) to the host, key-based (`ed25519` key installed by
`install-ssh-key.ps1`, default `%USERPROFILE%\.ssh\pf_fleet_ed25519`, user
`pacefactory`). Shell scripts are LF-only for this reason (`.gitattributes`).

## Client-side network requirements

SSH from the operator network (or VPN) to every deployment host. See
[site requirements](../network/site-requirements.md) and
[Update the fleet from Windows](../../how-to/update-fleet-from-windows.md).

## Payload summary

Shell script over stdin; `PF|...` marker lines back over stdout.

## Failure modes at the boundary

`UNREACHABLE` per server in the summary; a failure on one server never stops
the run (`scripts/remote/README.md` behaviour, now in the how-to).

## Variants

None.
