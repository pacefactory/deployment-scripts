---
title: "Corporate proxy"
type: reference
derived_from:
  - scripts/remote/update-server.sh
  - scripts/remote/README.md
  - build.sh
last_verified: 2026-09-10
verified_against: 9d0549a
---

# Corporate proxy

## What it connects to

An HTTP egress proxy on the client network that the deployment host must use
to reach Docker Hub, GitHub, Let's Encrypt and DNS APIs.

## Which Pacefactory services participate, and via which profile(s)

No compose service. The host shell sources `~/connect-to-proxy.sh` before
`git pull`, `build.sh` and `update.sh` (`scripts/remote/update-server.sh:39,72-80`);
its absence is a warning, not an error. The script's contents are per site and
not in this repository. `TODO(source)`: whether containers themselves (certbot,
expresso_server remote training) are proxy-aware; no fragment passes
`HTTP_PROXY`/`HTTPS_PROXY` into a container. The apigateway needs no proxy: its
only outbound connections are to upstream services on the compose network
([apigateway architecture](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/architecture/README.md)).

## Direction and protocol(s)

Outbound HTTP CONNECT from the host.

## Client-side network requirements

The proxy must allow the destinations listed in
[registry-egress](registry-egress.md) and [acme-dns](acme-dns.md). See
[site requirements](../network/site-requirements.md).

## Payload summary

Tunnelled HTTPS.

## Failure modes at the boundary

Pulls and `git pull` fail; the fleet payload reports `FAIL` with exit codes
12 (git) or 14 (update) (`scripts/remote/update-server.sh:27-35`).

## Variants

Per site.
