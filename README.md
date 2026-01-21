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


## Compose Files

### Profile System

Profiles are defined in `compose/docker-compose.{profile}.yml` files. Each profile can define metadata in the `x-pf-info` section that controls how the build script interacts with it.

#### Basic Profile Options

```yaml
x-pf-info:
  name: My Profile                    # Display name shown in prompts
  prompt: Enable My Profile?          # Custom prompt text
  description: What this profile does # Shown when user enters '?' for help
```

#### Settings

Profiles can define settings that will be prompted to the user. If the user enters a value, it will be written to `.ev.`. If the user does not provide a value, nothing will be written to `.env`

```yaml
x-pf-info:
  settings:
    MY_SETTING:
      default: default_value          # Default value shown in prompt
      description: What this setting does
```

#### Hidden Settings

Hidden settings are not prompted to the user. Unlike normal settings, They are automatically set to their default value when the profile is enabled. This is useful for internal variables that affect the compose output:

```yaml
x-pf-info:
  settings:
    MY_HIDDEN_VAR:
      default: some_value # The value that will be assigned to MY_HIDDEN_VAR in `.env`
      hidden: true
```

#### Dynamic Defaults with `default_var`

A setting can reference another variable for its default value using `default_var`. This allows sub-profiles to override defaults dynamically:

```yaml
x-pf-info:
  settings:
    MY_TAG:
      default: latest                 # Fallback if default_var is not set
      default_var: MY_TAG_OVERRIDE    # Use this variable's value as the default
```

When the user is prompted for `MY_TAG`, the prompt will show `[${MY_TAG_OVERRIDE}]` if that variable is set, otherwise `[latest]`.

### Sub-Profiles

Sub-profiles allow a parent profile connect optional profiles that are prompted immediately after the parent is enabled. This is useful for variations of a profile (e.g., enabling GPU support).

#### Defining Sub-Profiles

In the parent profile, list sub-profiles in the `sub-profiles` array:

```yaml
# docker-compose.myprofile.yml
x-pf-info:
  name: My Profile
  sub-profiles:
    - myprofile-variant
  settings:
    MY_TAG:
      default: latest
      default_var: MY_TAG_VARIANT
```

In the sub-profile, mark it with `sub-profile: true`:

```yaml
# docker-compose.myprofile-variant.yml
x-pf-info:
  name: My Profile Variant
  prompt: Enable variant for My Profile?
  sub-profile: true
  settings:
    MY_TAG_VARIANT:
      default: variant-tag
      hidden: true
```

The `sub-profile: true` flag tells the build script to skip this profile in the main loop (since it will be prompted via its parent's `sub-profiles` array).

#### How It Works

1. User enables the parent profile
2. Build script immediately prompts for each sub-profile listed in `sub-profiles`
3. If a sub-profile is enabled, its hidden settings are applied first
4. Parent profile settings are then prompted with the overridden defaults

### Example: Expresso with CUDA Support

The Expresso profile demonstrates sub-profiles with dynamic defaults:

**Parent profile (`docker-compose.expresso-010.yml`):**

```yaml
x-pf-info:
  name: Expresso profile
  prompt: Enable the Expresso profile?
  sub-profiles:
    - expresso-020-cuda
  settings:
    EXPRESSO_SERVER_TAG:
      default: latest
      default_var: EXPRESSO_SERVER_TAG_DEFAULT_GPU
    EXPRESSO_UI_TAG:
      default: latest

services:
  expresso_server:
    image: pacefactory/expresso_server:${EXPRESSO_SERVER_TAG:-${EXPRESSO_SERVER_TAG_DEFAULT_GPU:-latest}}
```

**Sub-profile (`docker-compose.expresso-020-cuda.yml`):**

```yaml
x-pf-info:
  name: Expresso CUDA
  prompt: Enable CUDA for Expresso?
  description: Should Expresso run with GPU support
  sub-profile: true
  settings:
    EXPRESSO_SERVER_TAG_DEFAULT_GPU:
      default: latest-gpu
      hidden: true

services:
  celery_worker:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu, utility, compute, video]
    environment:
      - PF_PREFER_GPU=true
```

**User Experience:**

```
Enable the Expresso profile? ([y]/n/?) y
 -> Will enable Expresso profile

Enable CUDA for Expresso? (y/[n]/?) y
 -> Will enable Expresso CUDA
EXPRESSO_SERVER_TAG [latest-gpu]:     # Default is 'latest-gpu' because CUDA was enabled
EXPRESSO_UI_TAG [latest]:
```

If the user had said "no" to CUDA, the prompt would show `EXPRESSO_SERVER_TAG [latest]:` instead.

