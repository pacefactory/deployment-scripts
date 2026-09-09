---
title: Roll back the MongoDB replica set
type: how-to
derived_from:
  - compose/docker-compose.base.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Roll back the MongoDB replica set

## Goal

Return the main `mongo` service to a standalone `mongod` without losing data.

## Prerequisites

- [ ] A reason: oplog write amplification confirmed by [Tune MongoDB performance](tune-mongodb-performance.md).
- [ ] A backup ([Back up volumes](back-up-volumes.md)).

## Steps

1. In `compose/docker-compose.base.yml` remove `--replSet rs0` and
   `--oplogSize …` from the `mongo` `command` list and delete the `healthcheck`
   block (which initialises the replica set).

2. Rebuild and relaunch:

   ```bash
   ./build.sh -q && ./update.sh
   ```

   mongod starts on the same data volume; the leftover replica set
   configuration in the `local` database is ignored and can optionally be
   removed by dropping that database. Journal-acknowledged writes in the
   clients keep working against a standalone node.

## Verify

```bash
docker exec <PREFIX>mongo mongo --quiet --eval 'rs.status()'   # error: not running with --replSet
docker compose ps mongo                                          # Up (no health status)
```

## Rollback

Revert the fragment change, `./build.sh -q && ./update.sh`; the healthcheck
re-initiates the replica set on the existing volume.

## Related

- [MongoDB deployment settings](../reference/mongodb.md)
