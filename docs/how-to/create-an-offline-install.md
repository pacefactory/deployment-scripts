---
title: "Create an offline install set"
type: how-to
derived_from:
  - scripts/offline/makeofflineinstall.sh
  - scripts/offline/install.sh
  - scripts/release/fetch-release.sh
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Create an offline install set

## Goal

Package Docker, docker compose, the images of a built compose file and an
installer into `install/<label>/` for a host with no internet access.

> **Warning:** this procedure and `scripts/offline/makeofflineinstall.sh` are
> untested against current versions of the software and are known to be
> broken (pinned Docker 20.10.9 and compose v2.0.1, Python-yq syntax). Treat
> this page as a record of what the script does, not as a working runbook.
> The one part that does work today is moving the scripts tree itself: the
> deployment-scripts release image can be `docker save`d and loaded on the
> offline host (see "Transfer the scripts tree" below). The old script does
> not do that; it packages images and an installer only.

## Prerequisites

- [ ] A built `docker-compose.yml` and `.env` in the repository root (run `./build.sh` first).
- [ ] `jq`, `docker compose`, and a `yq` that understands jq syntax: `makeofflineinstall.sh` requires the **Python** `yq` (`python3 -m pip install yq`, `scripts/offline/makeofflineinstall.sh:4,16,96`), which is the opposite of what `build.sh` needs. Run the two on different machines or switch PATH between them.
- [ ] Egress to download.docker.com, GitHub and Docker Hub; Docker Hub login.
- [ ] `<LABEL>`: `all` (every compose profile in the built file), a space-separated list of compose profile names, or empty for the base images only.

## Steps

1. Build the fileset:

   ```bash
   ./scripts/offline/makeofflineinstall.sh <LABEL>
   ```

   The script downloads a pinned Docker static build (`DOCKER_VERSION=20.10.9`)
   and compose `v2.0.1`, systemd unit files, pulls and saves every image of the
   selected profiles into `scv2.tar.gz`, and copies `install.sh` plus the
   backup script. `TODO(source)`: the pinned Docker and compose versions are
   older than the versions the root README says are confirmed to work; review
   before use.

2. Transfer `install/<LABEL>/` to the offline host and run the installer there:

   ```bash
   ./install.sh [<PROJECT_NAME>]
   ```

   It installs Docker from the tarball if `/usr/bin/docker` is missing
   (requires `sudo` and a reboot), installs the compose plugin, loads the
   images and runs `docker compose -p <PROJECT_NAME> up --detach`.

## Transfer the scripts tree

The scripts tree is distributed as the file-only image
`pacefactory/deployment-scripts` (see [Install or repair deployment-scripts on a server](install-deployment-scripts.md)),
so it travels the same way as the service images. On a machine with Docker Hub
access:

```bash
docker pull pacefactory/deployment-scripts:<TAG>
docker save pacefactory/deployment-scripts:<TAG> | gzip > deployment-scripts-<TAG>.tar.gz
```

On the offline host, load it and let the in-tree updater sync the install
directory from the local image instead of pulling
(`scripts/release/fetch-release.sh:12-13`):

```bash
gunzip -c deployment-scripts-<TAG>.tar.gz | docker load
cid=$(docker create pacefactory/deployment-scripts:<TAG> /pf-release)
tmp=$(mktemp -d) && docker cp "$cid:/." "$tmp/" && docker rm "$cid" >/dev/null
PF_INSTALL_DIR=~/scv2/git_clones/deployment-scripts bash "$tmp/scripts/release/fetch-release.sh" --from "$tmp"
rm -rf "$tmp"
```

On a host that already has the tree, `PF_RELEASE=<TAG> ./scripts/release/fetch-release.sh --no-pull`
does the same from the loaded image. `<TAG>` is a `vX.Y.Z` or `sha-<short>`
tag ([Publish a deployment-scripts release](publish-a-release.md)).

## Verify

On the offline host: `docker images` lists the saved images and
`docker compose -p <PROJECT_NAME> ps` shows the containers `Up`. For the
scripts tree, `cat ~/scv2/git_clones/deployment-scripts/.pf-release/VERSION`
shows the transferred `TAG`.

## Rollback

Delete `install/<LABEL>/` (the `install/` directory is gitignored).

## Related

- [Install or repair deployment-scripts on a server](install-deployment-scripts.md)
- [Container registry egress](../architecture/integrations/registry-egress.md)
- [`offline` profile](../architecture/profiles/offline.md) (unrelated: that profile disables autodelete for offline video processing)
