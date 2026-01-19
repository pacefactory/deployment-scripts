# deployment-scripts

Scripts and deployment configurations for deployment of SCV2 software.

# Overview

All containers should be run via Docker compose. Docker compose is the preferred
way to handle deployments. That is to say, it is not recommended to use the
individual deployment scripts.

There are a handful of profiles that can be enabled/disabled to run all or only
a subset of services. The profiles are listed below, and are explained in the
update script.

Notes for deployment

# Quick start

## Prerequisites

- Host OS must be Linux or MacOS
- Docker installed, with a recent version of docker compose. Docker 28.x.x + docker compose 2.35+ confirmed to work.
  - Check with `docker --version` and `docker compose version`

## Optional Dependencies

- `yq` is used for YAML parsing. `build.sh` can run without `yq` but is much faster if it is installed. Installation instructions are available in [YQ.md](YQ.md)
- CUDA support requires the host system to have specific driver's installed. Instructions for setting up CUDA support are available at [realtime/CUDA.md](https://github.com/pacefactory/scv2_realtime/blob/main/CUDA.md)

## Build script

Run the `build.sh` script to enable/disable compose profiles and set environment variables.

This will create a `.settings`, `.env`, and the compiled `docker-compose.yml` file.
`.settings` records the set of enabled profiles and project name.
`.env` records the list of environment variables that have been changed from their defaults.
`docker-compose.yml` is the generated compose output file, with all profiles and environment variables baked-in.

Flags:

- Pass `-q` to re-generate the `docker-compose.yml`, using existing settings in `.env` and `.settings`, with no user prompts.

## Update script

Run the `update.sh` script to pull the latest docker images and update the compose.

You will be prompted to 'reconfigure'. Pressing 'y' on this will invoke the `build.sh` script.

This script will attempt to run a migration script to ensure correct permissions are set for any docker volumes.

Flags

- Pass `-q` to skip all user prompts.
- Pass `--pull` to force-pull all latest images referenced in the compose file.

# Tools

## Record & Stitch Video

### **1. Record Video**

Records a raw RTSP stream from a specific camera to disk. This should be run as a **detached** container to avoid blocking your terminal during long recordings.

**Command:**

```bash
docker compose run -d --rm record_video <camera_id> <duration>

```

**Arguments:**

- `<camera_id>`: The specific camera ID (e.g., `cam_01`) as it is defined in the `realtime` container
- `<duration>`: Recording length. Accepts seconds (`300`) or shorthand (`10m`, `1h`, `2.5d`).

**Output:**

- Videos are saved to: `~/scv2/videos/<YYYY-MM-DD>/<camera_id>/`
- Files are automatically made writable by the host user.

---

### **2. Stitch Videos**

Scans a specific date folder, stitches all video segments for every camera into single files, and **deletes the source directories** by default.

**Command:**

```bash
docker compose run --rm stitch_videos <date_string> [options]

```

**Arguments:**

- `<date_string>`: The date folder to process (e.g., `2025-12-18`). Can be an absolute path to a date folder, if it isn't located at `~/scv2/videos/<YYYY-MM-DD>/`
- `--keep-source`: (Optional) If passed, the source directories and raw segments will **not** be deleted after stitching.

**Output:**

- Stitched files are saved to: `~/scv2/videos/<YYYY-MM-DD>/<camera_id>-<date>.mp4`
- Files are automatically made writable by the host user.

## Certbot

TODO: Document me!

# Advanced usage

## Backup realtime, auditgui and rdb configs

To easily backup configs from realtime, auditgui and rdb containers, you can run

```bash
./scripts/backup/backup_auditgui_realtime_rdb.sh
```

This will save backup tar files of each container's volumes in `~/scv2/backups`. The realtime backup only includes each camera's `/config` and `/resources` folder (excludes `/resources/backgrounds`)
