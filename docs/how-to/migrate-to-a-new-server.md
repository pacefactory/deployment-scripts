---
title: "Migrate a deployment to a new server"
type: how-to
derived_from:
  - scripts/backup_restore/backup_volume.sh
  - scripts/backup_restore/restore_volume.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Migrate a deployment to a new server

## Goal

Move a deployment's data volumes from an old host to a new one and bring the
deployment up there.

## Prerequisites

- [ ] New host prepared per [Build a deployment](build-a-deployment.md) prerequisites, repository cloned, `./build.sh` run with the same profile selection (copy `.settings` and `.env` from the old host).
- [ ] Decide the path by network situation (below): `<USER>@<NEW_HOST>`, `<USER>@<OLD_HOST>`.
- [ ] Downtime window on the old host.

## Steps

Same network, zero disk on the old server:

```bash
# old server
./scripts/backup_restore/backup_volume.sh --mode ssh -r <USER>@<NEW_HOST>
# new server
./scripts/backup_restore/restore_volume.sh -i ~/scv2_backups/<BACKUP_FOLDER>
```

Same network, new server pulls:

```bash
# old server
./scripts/backup_restore/backup_volume.sh
# new server
./scripts/backup_restore/restore_volume.sh --mode ssh -r <USER>@<OLD_HOST> -p <REMOTE_BACKUP_PATH>
```

Same network, volume to volume with no intermediate files (no restore step):

```bash
# old server
./scripts/backup_restore/backup_volume.sh --mode direct -r <USER>@<NEW_HOST> [--remote-name <NEW_PROJECT>]
```

Servers not on the same network:

```bash
# old server: one archive at a time, transfer each by USB or cloud storage when prompted
./scripts/backup_restore/backup_volume.sh --mode sequential
# new server
./scripts/backup_restore/restore_volume.sh -i <PATH_TO_TRANSFERRED_FILES>
```

Then on the new server run `./update.sh`.

## Verify

`docker compose ps` on the new server shows every container `Up`; the web UI
at `http://<NEW_HOST>/scv3/` shows the migrated cameras and history. Keep the
old host stopped until verified.

## Rollback

Start the old host's project again (`./update.sh` there); its volumes are
untouched by every mode.

## Related

- [Backup and restore CLI reference](../reference/backup-restore-cli.md)
