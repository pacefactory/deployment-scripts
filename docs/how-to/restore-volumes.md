---
title: Restore volumes
type: how-to
derived_from:
  - scripts/backup_restore/restore_volume.sh
  - scripts/backup_restore/volumes.json
  - scripts/common/backup_utils.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Restore volumes

## Goal

Load volume archives into the Docker volumes of a deployment.

## Prerequisites

- [ ] A backup folder or `.tar.gz` archive produced by `backup_volume.sh`, local or on the old server (`<OLD_HOST>`).
- [ ] The target compose project built at least once so its volumes exist, or accept that the script creates them (`<PROJECT_NAME>`).
- [ ] Downtime window: the project is stopped during the restore.

## Steps

1. Restore from a local folder or archive:

   ```bash
   ./scripts/backup_restore/restore_volume.sh -i ~/scv2_backups/<BACKUP_FOLDER_OR_ARCHIVE> [-n <PROJECT_NAME>]
   ```

2. Or pull directly from the old server over SSH:

   ```bash
   ./scripts/backup_restore/restore_volume.sh --mode ssh -r <USER>@<OLD_HOST> -p <REMOTE_BACKUP_PATH>
   ```

3. Restart the project when prompted, or run `./update.sh`.

## Verify

```bash
docker volume ls | grep <PROJECT_NAME>_
docker run --rm -v <PROJECT_NAME>_dbserver-data:/data alpine du -sh /data
docker compose ps
```

## Rollback

Restore from the previous backup, or stop the project and remove the affected
volumes before restoring again (`docker volume rm <PROJECT_NAME>_<suffix>`;
never `docker compose down -v`, which removes every project volume).

## Related

- [Backup and restore CLI reference](../reference/backup-restore-cli.md)
- [Back up volumes](back-up-volumes.md)
