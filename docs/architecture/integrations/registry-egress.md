---
title: "Container registry and GitHub egress"
type: reference
derived_from:
  - update.sh
  - scripts/common/runYq.sh
  - scripts/Dockerfile.build
  - scripts/installYq.sh
  - scripts/offline/makeofflineinstall.sh
  - scripts/remote/update-server.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Container registry and GitHub egress

## What it connects to

- `ext_registry`: Docker Hub, where every `pacefactory/*` image and the
  third-party images are pulled from.
- `ext_github`: GitHub, for `git pull` of this repository and for the `yq`
  and docker compose binaries.

## Which Pacefactory services participate, and via which profile(s)

No compose service. Host-side tooling:

- `update.sh` runs `docker login` and `docker compose pull` when `DOCKER_PULL`
  is true (`update.sh:71-98`).
- `scripts/common/runYq.sh` pulls `mikefarah/yq:latest` when no `yq` binary is
  on PATH (`scripts/common/runYq.sh:26-32`).
- `scripts/installYq.sh` and `scripts/Dockerfile.build` download `yq` and the
  compose plugin from GitHub releases.
- `scripts/offline/makeofflineinstall.sh` pulls images and downloads docker
  binaries to build an offline install set. The script is broken against
  current software versions (see [Create an offline install](../../how-to/create-an-offline-install.md)).
- `scripts/remote/update-server.sh` runs `git pull --ff-only` on each server
  (`scripts/remote/update-server.sh:86-92`).

## Direction and protocol(s)

Outbound HTTPS (443) from the deployment host, through the corporate proxy
where one is configured. Docker Hub requires a `docker login` with credentials
stored on the host account.

## Client-side network requirements

Allow-list `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com`
(Docker Hub pull path; `TODO(source)`: confirm current hostnames),
`github.com` and `objects.githubusercontent.com`. Sites with no egress would need the
[offline install](../../how-to/create-an-offline-install.md), which is currently broken.

## Payload summary

Container images; git objects; static binaries.

## Failure modes at the boundary

`update.sh` exits 0 even when the pull fails, and skips the `up` step; the
fleet payload detects this by the absence of "Deployment complete"
(`scripts/remote/update-server.sh:150-164`).

## Variants

Offline install set: `scripts/offline/`.
