---
title: "Back up volumes"
type: how-to
derived_from:
  - scripts/backup_restore/backup_volume.sh
  - scripts/backup_restore/volumes.json
  - scripts/common/backup_utils.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Back up volumes

## Goal

Archive the deployment's data volumes locally or to another server.

## Prerequisites

- [ ] Downtime window: the script stops the compose project (`docker compose stop --timeout 600`) before reading volumes and offers to restart it afterwards.
- [ ] Local mode: enough free disk for the compressed volumes (see step 1).
- [ ] Remote modes: SSH access `<USER>@<NEW_HOST>` with Docker installed there.
- [ ] `<PROJECT_NAME>` if auto-detection picks the wrong project.

## Steps

1. Pre-flight the disk space:

   ```bash
   ./scripts/backup_restore/backup_volume.sh --check-only
   ```

   The table compares volume sizes with free space and recommends `--mode ssh`
   or `--mode sequential` when local space is short.

2. Pick a mode:

   ```bash
   # local folder (default ~/scv2_backups/<timestamp>)
   ./scripts/backup_restore/backup_volume.sh

   # stream to another server, zero local disk
   ./scripts/backup_restore/backup_volume.sh --mode ssh -r <USER>@<NEW_HOST>

   # one volume at a time, transfer between volumes (no network between servers)
   ./scripts/backup_restore/backup_volume.sh --mode sequential

   # straight into Docker volumes on the new server, zero disk on both
   ./scripts/backup_restore/backup_volume.sh --mode direct -r <USER>@<NEW_HOST> [--remote-name <NEW_PROJECT>]
   ```

   Add `--no-images` to skip dbserver `.jpg` files without being asked.

3. Answer the restart prompt when the backup finishes.

## Verify

Local and ssh modes: list the destination folder and check one archive:

```bash
ls -lh ~/scv2_backups/<TIMESTAMP>/
tar -tzf ~/scv2_backups/<TIMESTAMP>/<ARCHIVE>.tar.gz | head
```

Direct mode: on the new server, `docker volume ls | grep <PROJECT_NAME>_` shows
the volumes listed in `scripts/backup_restore/volumes.json`.

## Rollback

Not applicable; backups are additive.

## Related

- [Backup and restore CLI reference](../reference/backup-restore-cli.md) (options, volumes covered and not covered)
- [Restore volumes](restore-volumes.md)
- [Migrate to a new server](migrate-to-a-new-server.md)
