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

## MongoDB

The main `mongo` service runs with a bounded memory footprint and as a single-node replica set. Sizing guidance, how the replica set is initialized, verification and rollback steps are documented in [MONGODB.md](MONGODB.md).

## Build script

Run the `build.sh` script to enable/disable compose profiles and set environment variables.

This will create a `.settings`, `.env`, and the compiled `docker-compose.yml` file.
`.settings` records the set of enabled profiles and project name.
`.env` records the list of environment variables that have been changed from their defaults.
`docker-compose.yml` is the generated compose output file, with all profiles and environment variables baked-in.

Flags:

- Pass `-q` to re-generate the `docker-compose.yml`, using existing settings in `.env` and `.settings`, with no user prompts.
  A quiet run also writes `.settings` back, so the profile selection and project name it used are recorded rather than re-derived on the next run.

When a new release changes the default environment variables, the resulting `.env`
diff is printed. Interactively you are asked to confirm it; with `-q` (or any run
without a terminal on stdin, such as the fleet tooling) the new defaults are applied
automatically. Either way the previous file is kept as `.env.backup`.

## Update script

Run the `update.sh` script to pull the latest docker images and update the compose.

You will be prompted to 'reconfigure'. Pressing 'y' on this will invoke the `build.sh` script.

This script will attempt to run a migration script to ensure correct permissions are set for any docker volumes.

Flags

- Pass `-q` to skip all user prompts.
- Pass `--pull` to force-pull all latest images referenced in the compose file.

## Upgrade notes

### Audit processing: per-entry segment trimming (2026-07)

`PF_TRIM_SEGMENTS_TO_BLOCK` has been removed. Segment trimming at processing-block boundaries is
now controlled **per entry** in the audit config (webgui → Advanced Entry Edit), is ON by default
for all station entries and most generic entries, and trimmed pieces are stitched back together
in storage. A stale `PF_TRIM_SEGMENTS_TO_BLOCK` value in an existing `.env` is harmless (nothing
reads it); re-run `./build.sh` to regenerate the compose without it.

A new setting `PF_PROCESS_BLOCK_MAX_LOOKBACK_MINUTES` (default 240) caps the per-entry source-data
lookback that audit processing now derives from each entry's duration parameters.

**Global kill switch (2026-07):** the whole trim/stitch/derived-lookback feature is additionally
gated by `PF_ENABLE_SEGMENT_TRIM_STITCH`, which **defaults to false** pending performance
evaluation at scale. While false, audit processing behaves exactly as before the feature landed
(legacy drop rule, fixed fetch windows, no stitch pass) and per-entry trim settings are ignored;
stored records are never modified by the switch. Set it to `true` to enable the feature.

Segment data stored **before** this upgrade is deliberately left as-is: segments dropped or
trimmed under the old rules (including at sites that ran `PF_TRIM_SEGMENTS_TO_BLOCK=true`) carry
no provenance flags and are never touched by the new stitching. Only blocks processed after the
upgrade get the new behavior.

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

## HTTPS without Certbot (direct SSL)

The `https-no-certbot` profile ("Enable HTTPS (via direct SSL)") serves an
existing certificate instead of provisioning one through certbot. The
apigateway (and, by extension, the `mqtts-public` sub-profile) expects an
**unencrypted** cert/key pair at:

```
credentials/ssl/live/<FQDN>/fullchain.pem
credentials/ssl/live/<FQDN>/privkey.pem
```

where `<FQDN>` is the domain end users browse to (e.g.
`serverhostname001.region.company.com`) and the value you enter for
`SERVER_NAME` during `./build.sh`.

If you were handed a single password-protected PKCS#12 bundle (`.pfx` /
`.p12`) containing the full chain plus the private key, use
`scripts/import-ssl-cert.sh` to convert and place the files for you:

```bash
# FQDN is taken from the file name by default, e.g.
#   serverhostname001.region.company.com.pfx
#       -> credentials/ssl/live/serverhostname001.region.company.com/
./scripts/import-ssl-cert.sh ~/certs/serverhostname001.region.company.com.pfx

# Or derive the FQDN from the certificate's Common Name:
./scripts/import-ssl-cert.sh --from-cn ~/certs/wildcard-export.pfx

# Or set it explicitly:
./scripts/import-ssl-cert.sh --server-name app.example.com ~/certs/export.pfx
```

The script prompts for the bundle password (or accept it via
`--password-file`, the `PFX_PASSWORD` environment variable, or `--password`),
runs the appropriate `openssl pkcs12` commands (including the `-legacy`
fallback needed for Windows/IIS exports under OpenSSL 3), verifies the key
matches the certificate, and writes `fullchain.pem` (leaf first, then any
intermediates) and `privkey.pem` (mode `0600`). Run `--help` for all options.

Afterwards, run `./build.sh`, enable "Enable HTTPS (via direct SSL)", set
`SERVER_NAME` to the same `<FQDN>`, then `./update.sh`.

> The generated `privkey.pem` is unencrypted, so no `privkey.pass` file is
> needed. (The apigateway also supports an encrypted `privkey.pem` paired with
> a single-line `privkey.pass`; see the profile description in
> `compose/docker-compose.https-no-certbot.yml`.)

## HTTP to HTTPS redirect

Whenever any `https-*` profile is enabled (`https-manual`, `https-godaddy`,
`https-digitalocean`, or `https-no-certbot`), the apigateway stops serving the
app over plain HTTP and redirects those clients to HTTPS instead. A request for
`http://<FQDN>/scv3/` is answered with `307 Location: https://<FQDN>/scv3/`.

The redirect is a `307` rather than the more common `301`, so that the request
method and body survive it (a `301` would silently downgrade an API client's
`POST` to a `GET`) and so that browsers do not cache the upgrade permanently —
a deployment that later drops its `https-*` profile starts answering over HTTP
again without users having to clear their cache.

HTTP stays published on `HTTP_PORT` (default `80`) purely to serve the
redirect; there is no need to change it. If you moved HTTPS off the default
port with `HTTPS_PORT`, the redirect target picks that port up automatically:
each `https-*` profile passes it to the apigateway as `HTTPS_PUBLIC_PORT`, and
the container appends `:<port>` to the redirect URL when it is not `443`.

> On a deployment that is still waiting on its real certificate, the apigateway
> serves a temporary self-signed one (see above). The redirect sends HTTP
> clients to that endpoint too, so browsers will show a certificate warning
> where they previously got plain HTTP. Installing the real certificate and
> running `./update.sh` clears it.

# MQTT broker access

The `pf_mosquitto` MQTT broker exposes three listeners. Which ones are
reachable from outside the docker network depends on which profiles are
enabled at build time:

| Listener | Port | Profile required                                | Default            | Notes                            |
| -------- | ---- | ----------------------------------------------- | ------------------ | -------------------------------- |
| MQTT     | 1883 | `mqtt-public` (sub-profile of `base`)           | enabled            | Plain TCP MQTT                   |
| MQTTS    | 8883 | `mqtts-public` (sub-profile of every `https-*`) | enabled with HTTPS | TLS using the same cert as nginx |

## Plain MQTT on port 1883

The `mqtt-public` sub-profile of `base` controls whether port 1883 is
published on the host. It is enabled by default. Disable it during
`./build.sh` (or remove `mqtt-public` from `.settings`'s `SCV2_PROFILES`)
on internet-facing deployments where only TLS-protected MQTTS should be
reachable.

The host port is configurable via `PF_MOSQUITTO_PUBLIC_PORT` (default
`1883`).

## MQTTS on port 8883

When any `https-*` profile is enabled (`https-manual`, `https-godaddy`,
`https-digitalocean`, or `https-no-certbot`), build.sh also prompts for
the `mqtts-public` sub-profile (default `y`). When enabled, the same SSL
certificate that nginx uses is mounted into `pf_mosquitto` and the
broker's entrypoint script enables an MQTTS listener on port 8883.

Each `https-*` profile contributes the cert source via two hidden
settings consumed by `mqtts-public`:

| Variable            | `https-no-certbot`   | `https-manual` | `https-godaddy`    | `https-digitalocean` |
| ------------------- | -------------------- | -------------- | ------------------ | -------------------- |
| `MQTTS_CERT_SOURCE` | `../credentials/ssl` | `certbot`      | `certbot`          | `certbot`            |
| `MQTTS_FQDN_SUFFIX` | (empty)              | (empty)        | `.pacefactory.com` | `.pacefactory.dev`   |

What happens under the hood when `mqtts-public` is on:

- `${MQTTS_CERT_SOURCE}` is mounted read-only into `pf_mosquitto` at
  `/etc/mosquitto-tls/`.
- `SERVER_NAME=${SERVER_NAME}${MQTTS_FQDN_SUFFIX}` is passed to the
  `pf_mosquitto` container.
- On startup, `docker-entrypoint.sh` looks for
  `/etc/mosquitto-tls/live/${SERVER_NAME}/{fullchain.pem,privkey.pem}` and,
  if found, copies them into `/run/mosquitto-tls/` (owned by the
  `mosquitto` user) and generates a TLS listener config in
  `/mosquitto/config/conf.d/tls.conf`. Staging the files is required
  because Let's Encrypt writes `privkey.pem` as `0600 root:root`, which
  the unprivileged mosquitto process can't read directly.
- If `privkey.pem` is encrypted, place the password (single line) in
  `privkey.pass` next to it. The entrypoint will decrypt the key into the
  runtime-only path before mosquitto reads it.
- If the cert files are missing at runtime, MQTTS is silently skipped
  &mdash; the broker still starts up with the plain 1883/7575 listeners.

The host port is configurable via `MQTTS_PUBLIC_PORT` (default `8883`).
Clear the variable in `.env` to keep the listener internal-only.

To run HTTPS for the web UI without exposing native MQTTS, answer `n` to
`Expose MQTTS on port 8883?` during build, or remove `mqtts-public` from
`SCV2_PROFILES` in `.settings`.

### Connecting clients

```
# Plain
mosquitto_sub -h <server> -p 1883 -u admin -P pfadminpw -t '#'

# TLS (MQTTS)
mosquitto_sub -h <server> -p 8883 --capath /etc/ssl/certs -u admin -P pfadminpw -t '#'
```

# Ghosting Configuration

The platform supports tiered ghosting enforcement to control access to unghosted snapshot images.

## Deployment Modes

| Mode               | `WEBGUI_FORCE_GHOSTING` | `DBSERVER_DISABLE_SNAPSHOT_IMAGES` | Description                                                                    |
| ------------------ | ----------------------- | ---------------------------------- | ------------------------------------------------------------------------------ |
| **Hard** (default) | `true`                  | `true`                             | Maximum security. Webgui locked, dbserver snapshot image endpoints disabled.   |
| **Soft**           | `true`                  | `false`                            | Webgui locked but `UNGHOSTED_CAMERA_LIST` works. DBServer endpoints available. |
| **None**           | `false`                 | `false`                            | Full user control over ghosting toggle.                                        |

## Environment Variables

### WEBGUI_FORCE_GHOSTING

- **Default:** `true`
- Controls whether the ghosting toggle in the web UI is locked.

### WEBGUI_UNGHOSTED_CAMERA_LIST

- **Default:** `""` (empty)
- Comma-separated list of camera names that can be displayed unghosted in the webgui.
- Only effective when `WEBGUI_FORCE_GHOSTING=true` and `DBSERVER_DISABLE_SNAPSHOT_IMAGES=false` (soft mode).

### WEBGUI_DEFAULT_GHOSTING_TYPE

- **Default:** `ghosted`
- Ghosting style the webgui starts with. One of `no_image` (Outline), `edges` (Dark Mode),
  `edges_inverted` (Light Mode), `ghosted` (Ghosted), `ghosted_blur` (Blur), `color_invert` (Invert).
- Only sets the starting value: users can still pick a different style from the ghosting settings
  dropdown for their session. Independent of `WEBGUI_FORCE_GHOSTING`, which locks whether ghosting
  can be turned off at all.
- An unrecognized value falls back to `ghosted` in the webgui and social app.

### DBSERVER_DISABLE_SNAPSHOT_IMAGES

- **Default:** `true`
- When `true`, snapshot image endpoints are not registered in dbserver (hard enforcement).
- Gifwrapper automatically reads snapshots directly from the shared volume when this is enabled.

## Migration Notes

- **New deployments** default to hard enforcement (both variables `true`).
- **Existing deployments** using `UNGHOSTED_CAMERA_LIST` should set `DBSERVER_DISABLE_SNAPSHOT_IMAGES=false` to maintain soft enforcement.

# Advanced usage

## Backup & Restore Docker Volumes

All backup/restore scripts are located in `scripts/backup_restore/`. The volume list is defined in `scripts/backup_restore/volumes.json`.

### Backup

```bash
./scripts/backup_restore/backup_volume.sh [OPTIONS]
```

| Option                   | Description                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------- |
| `-n, --name NAME`        | Project name (default: auto-detect)                                                   |
| `-o, --output DIR`       | Local backup output directory (default: `~/scv2_backups`)                             |
| `-m, --mode MODE`        | Backup mode: `local`, `ssh`, `sequential`, `direct`                                   |
| `-r, --remote USER@HOST` | Remote destination for `ssh`/`sequential`/`direct` mode                               |
| `-p, --remote-path PATH` | Remote path (default: `~/scv2_backups/<timestamp>`)                                   |
| `--remote-name NAME`     | Project name on the remote server (for `direct` mode; defaults to local project name) |
| `--no-images`            | Skip `.jpg` files from dbserver (non-interactive)                                     |
| `--check-only`           | Run disk space pre-flight check and exit                                              |
| `-h, --help`             | Show help                                                                             |

**Backup modes:**

- **`local`** (default) -- Back up all volumes to a local folder. Runs a disk space pre-flight check and warns if space is tight.
- **`ssh`** -- Stream each volume directly to a remote server via SSH. Uses **zero local disk space**. Requires the old and new servers to be on the same network.
- **`sequential`** -- Back up one volume at a time, prompt to transfer it, then delete the local copy before backing up the next. Max disk usage = the single largest compressed volume. Works in any network situation.
- **`direct`** -- Stream volumes directly from old server Docker volumes into new server Docker volumes via SSH. Uses **zero disk space on both servers** (no intermediate `.tar.gz` files). Run from the old server; requires SSH access to the new server with Docker installed. Supports `--remote-name` if project names differ across servers.

### Restore

```bash
./scripts/backup_restore/restore_volume.sh [OPTIONS]
```

| Option                   | Description                                    |
| ------------------------ | ---------------------------------------------- |
| `-i, --input PATH`       | Path to backup folder or `.tar.gz` archive     |
| `-n, --name NAME`        | Project name (default: auto-detect)            |
| `-m, --mode MODE`        | Restore mode: `local`, `ssh`                   |
| `-r, --remote USER@HOST` | Remote source (the old server, for `ssh` mode) |
| `-p, --remote-path PATH` | Remote path containing backup files            |
| `-h, --help`             | Show help                                      |

**Restore modes:**

- **`local`** (default) -- Restore from a local backup folder or `.tar.gz` archive.
- **`ssh`** -- Pull backup files directly from a remote server via SSH into Docker volumes. Uses **zero local archive storage**.

### Pre-flight disk check

Before starting a migration, check whether the server has enough space for a local backup:

```bash
./scripts/backup_restore/backup_volume.sh --check-only
```

This prints a table of volume sizes vs. available disk space and recommends `--mode ssh` or `--mode sequential` if space is insufficient.

### Migration workflows

**Same network (zero disk usage on old server):**

```bash
# On old server:
./scripts/backup_restore/backup_volume.sh --mode ssh -r user@newserver

# On new server:
./scripts/backup_restore/restore_volume.sh -i ~/scv2_backups/<backup-folder>
```

**Same network (new server pulls from old):**

```bash
# On old server: run a standard local backup (if space allows)
./scripts/backup_restore/backup_volume.sh

# On new server: pull directly from old server
./scripts/backup_restore/restore_volume.sh --mode ssh -r user@oldserver -p /path/to/backup
```

**Same network (zero disk on both servers, direct volume-to-volume):**

```bash
# On old server: stream directly into Docker volumes on new server
./scripts/backup_restore/backup_volume.sh --mode direct -r user@newserver

# If the project name differs on the new server:
./scripts/backup_restore/backup_volume.sh --mode direct -r user@newserver --remote-name newproject
```

No restore step needed -- data goes directly into Docker volumes on the new server.

**Servers not on the same network:**

```bash
# On old server: back up one volume at a time
./scripts/backup_restore/backup_volume.sh --mode sequential
# (transfer each file via USB, cloud storage, etc. when prompted)

# On new server: restore from wherever the files were placed
./scripts/backup_restore/restore_volume.sh -i /path/to/backup-files
```

## Remote Fleet Updates (from Windows)

`scripts/remote/` contains tooling to run `git pull` + `build.sh -q` +
`update.sh -q` across many servers over ssh from a Windows machine (built-in
OpenSSH client only, no admin rights), with per-server health checks, detection
of pacefactory images pinned to non-`latest` tags, and a summary report.
See [scripts/remote/README.md](scripts/remote/README.md).

## Compose Files

### Profile System

Profiles are defined in `compose/docker-compose.{profile}.yml` files. Each profile can define metadata in the `x-pf-info` section that controls how the build script interacts with it.

#### Basic Profile Options

```yaml
x-pf-info:
  name: My Profile # Display name shown in prompts
  prompt: Enable My Profile? # Custom prompt text
  description: What this profile does # Shown when user enters '?' for help
```

#### Settings

Profiles can define settings that will be prompted to the user. If the user enters a value, it will be written to `.ev.`. If the user does not provide a value, nothing will be written to `.env`

```yaml
x-pf-info:
  settings:
    MY_SETTING:
      default: default_value # Default value shown in prompt
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
      default: latest # Fallback if default_var is not set
      default_var: MY_TAG_OVERRIDE # Use this variable's value as the default
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

The Expresso profile itself is mandatory (build.sh force-enables it without prompting), so the user is only asked about its sub-profiles and settings:

```
 -> Will enable Expresso profile

Enable CUDA for Expresso? (y/[n]/?) y
 -> Will enable Expresso CUDA
EXPRESSO_SERVER_TAG [latest-gpu]:     # Default is 'latest-gpu' because CUDA was enabled
EXPRESSO_UI_TAG [latest]:
```

If the user had said "no" to CUDA, the prompt would show `EXPRESSO_SERVER_TAG [latest]:` instead.
