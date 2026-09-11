---
title: "Container registry and GitHub egress"
type: reference
derived_from:
  - update.sh
  - scripts/common/runYq.sh
  - scripts/common/dockerLogin.sh
  - scripts/release/fetch-release.sh
  - scripts/release/stage.sh
  - scripts/release/Dockerfile
  - .github/workflows/ci.yml
  - scripts/Dockerfile.build
  - scripts/installYq.sh
  - scripts/offline/makeofflineinstall.sh
  - scripts/remote/update-server.sh
  - scripts/docs/flows.tsv
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Container registry and GitHub egress

## What it connects to

- `ext_registry`: Docker Hub, where every `pacefactory/*` service image, the
  third-party images and, since the repository went private, the
  deployment-scripts tree itself (`pacefactory/deployment-scripts`, a
  file-only `FROM scratch` image, `scripts/release/Dockerfile:10-11`) are
  pulled from.
- `ext_github`: GitHub, for the public bootstrap `install.sh` served by
  GitHub Pages at `get.pacefactory.dev` (repository `pacefactory/deploy`) and
  for the `yq` and docker compose binaries. Servers no longer `git pull` this
  repository.

## Which Pacefactory services participate, and via which profile(s)

No compose service. Host-side tooling:

- `update.sh` runs `docker login` and `docker compose pull` when `DOCKER_PULL`
  is true (`update.sh:71-98`).
- `scripts/release/fetch-release.sh` pulls `${PF_IMAGE}:${PF_RELEASE}`
  (`scripts/release/fetch-release.sh:121`), retries once after a
  `docker login` with the server's token file when the pull fails
  (`scripts/release/fetch-release.sh:124-131`, `scripts/common/dockerLogin.sh:81`),
  and extracts the image with `docker create` / `docker cp`
  (`scripts/release/fetch-release.sh:147-148`). The public bootstrap does the
  same pull and hands off to it.
- `scripts/remote/update-server.sh` runs `fetch-release.sh` on each server
  (`scripts/remote/update-server.sh:140-150`).
- `scripts/common/runYq.sh` pulls `mikefarah/yq:latest` when no `yq` binary is
  on PATH (`scripts/common/runYq.sh:26-32`).
- `scripts/installYq.sh` and `scripts/Dockerfile.build` download `yq` and the
  compose plugin from GitHub releases.
- `scripts/offline/makeofflineinstall.sh` pulls images and downloads docker
  binaries to build an offline install set. The script is broken against
  current software versions (see [Create an offline install](../../how-to/create-an-offline-install.md));
  `docker save` of the release image is the working offline path for the
  scripts tree.
- Publishing side: `.github/workflows/ci.yml` pushes the release image from
  GitHub Actions with the organization-level `DOCKER_USER` / `DOCKER_PAT`
  credentials (`.github/workflows/ci.yml:89-94`).

## Direction and protocol(s)

Outbound HTTPS (443) from the deployment host, through the corporate proxy
where one is configured. Docker Hub requires a standing `docker login` as the
organization user `pacefactory`, made with a per-server Organization Access
Token stored in `~/scv2/docker_oat.sh` (`scripts/common/dockerLogin.sh:5-13`).
The token is the single revocation point for both service images and the
scripts tree. Issuance and scopes are in the Pacefactory Deployment Guide
(`TODO(source)`).

## Client-side network requirements

Allow-list `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com`
(Docker Hub pull path; `TODO(source)`: confirm current hostnames),
`get.pacefactory.dev` (install and repair only), `github.com` and
`objects.githubusercontent.com` (yq and compose binaries). Sites with no
egress transfer the release image with `docker save` and use the
[offline install](../../how-to/create-an-offline-install.md) page for the
rest, which is currently broken for the images.

## Payload summary

Container images (services, and the file-only release image whose manifest is
listed in `.pf-release/MANIFEST`, `scripts/release/stage.sh:99-103`); a bash
script; static binaries.

## Failure modes at the boundary

`update.sh` exits 0 even when the pull fails, and skips the `up` step; the
fleet payload detects this by the absence of "Deployment complete"
(`scripts/remote/update-server.sh:217-233`). `fetch-release.sh` exits 1 with
a remediation naming the token file when the release pull fails
(`scripts/release/fetch-release.sh:132-140`); the fleet payload maps that to
exit 12 and an unmigrated server to 17 (`scripts/remote/update-server.sh:41-50`).

## Variants

Offline: `docker save` / `docker load` of the release image plus
`fetch-release.sh --from <extracted dir>` or `--no-pull`; `scripts/offline/`
for the service images.
