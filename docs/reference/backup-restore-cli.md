---
title: Backup and restore CLI
type: reference
derived_from:
  - scripts/backup_restore/backup_volume.sh
  - scripts/backup_restore/restore_volume.sh
  - scripts/backup_restore/volumes.json
  - scripts/common/backup_utils.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Backup and restore CLI

Options of the two volume scripts, from their `usage()` text. Procedures:
[Back up volumes](../how-to/back-up-volumes.md), [Restore volumes](../how-to/restore-volumes.md),
[Migrate to a new server](../how-to/migrate-to-a-new-server.md).

## Volumes covered

`scripts/backup_restore/volumes.json` lists the volumes both scripts handle
(suffix appended to the project name):

| Name | Volume suffix |
|---|---|
| dbserver | `_dbserver-data` |
| mongo | `_mongodata` |
| realtime | `_realtime-data` |
| auditgui | `_webgui-data` |
| social_video | `_social_video_server-data` |
| nodered | `_nodered-data` |
| rdb | `_relational_dbserver-data` |
| ape | `_ape-data` |
| ape-tsdb | `_ape_timescaledb-data` |

Not covered: `mosquitto-data`, `data_interconnector-data`,
`service_dtreeserver-data`, `audit_processing-data`, `expresso-data`,
`mongodata_exp`, `autozone*`, `perf_eval-*`, `ntfy-*`, `swift-labeler-*`,
`certbot`. `TODO(source)`: whether these omissions are intentional.

Both scripts stop the compose project before touching volumes
(`scripts/common/backup_utils.sh:56-66`, `docker compose stop --timeout 600`)
and offer to restart it afterwards.

## `backup_volume.sh`

```text
Usage: backup_volume.sh [OPTIONS]
  -n, --name NAME         Project name (default: auto-detect)
  -o, --output DIR        Local backup output directory (default: ~/scv2_backups)
  -m, --mode MODE         Backup mode: local (default), ssh, sequential, direct
  -r, --remote USER@HOST  Remote destination for ssh/sequential/direct mode
  -p, --remote-path PATH  Remote path for ssh mode (default: ~/scv2_backups/<timestamp>)
      --remote-name NAME  Project name on remote server (for direct mode; default: local name)
      --no-images         Skip .jpg files from dbserver (non-interactive)
      --check-only        Run disk space pre-flight check and exit
  -h, --help              Show this help message
```

| Mode | Behaviour |
|---|---|
| `local` | All volumes to a local folder as `.tar.gz`, after a disk-space pre-flight check. |
| `ssh` | Stream each volume to the remote over SSH; zero local disk. |
| `sequential` | One volume at a time; prompt to transfer, delete, continue. Max local usage is the largest single archive. |
| `direct` | Stream from local Docker volumes straight into Docker volumes on the remote; zero disk on both. Run from the old server. |

## `restore_volume.sh`

```text
Usage: restore_volume.sh [OPTIONS]
  -i, --input PATH        Path to backup folder or .tar.gz archive (local restore)
  -n, --name NAME         Project name (default: auto-detect)
  -m, --mode MODE         Restore mode: local (default), ssh
  -r, --remote USER@HOST  Remote source (the OLD server, for ssh mode)
  -p, --remote-path PATH  Remote path containing backup files (required for ssh mode)
  -h, --help              Show this help message
```

## Deprecated scripts

`scripts/online/backup.sh` and `scripts/online/restore.sh` exit immediately
with "Script outdated. Do not use." (`scripts/online/backup.sh:3-4`).
