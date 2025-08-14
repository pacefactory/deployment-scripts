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

# Advanced usage

## Backup realtime, auditgui and rdb configs

To easily backup configs from realtime, auditgui and rdb containers, you can run

```bash
./scripts/backup/backup_auditgui_realtime_rdb.sh
```

This will save backup tar files of each container's volumes in `~/scv2/backups`. The realtime backup only includes each camera's `/config` and `/resources` folder (excludes `/resources/backgrounds`)
