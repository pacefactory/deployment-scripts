---
title: "Create an offline install set"
type: how-to
derived_from:
  - scripts/offline/makeofflineinstall.sh
  - scripts/offline/install.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Create an offline install set

## Goal

Package Docker, docker compose, the images of a built compose file and an
installer into `install/<label>/` for a host with no internet access.

> **Warning:** this procedure and `scripts/offline/makeofflineinstall.sh` are
> untested against current versions of the software and are known to be
> broken (pinned Docker 20.10.9 and compose v2.0.1, Python-yq syntax). Treat
> this page as a record of what the script does, not as a working runbook.

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

## Verify

On the offline host: `docker images` lists the saved images and
`docker compose -p <PROJECT_NAME> ps` shows the containers `Up`.

## Rollback

Delete `install/<LABEL>/` (the `install/` directory is gitignored).

## Related

- [Container registry egress](../architecture/integrations/registry-egress.md)
- [`offline` profile](../architecture/profiles/offline.md) (unrelated: that profile disables autodelete for offline video processing)
