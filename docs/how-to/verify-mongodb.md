---
title: Verify MongoDB state
type: how-to
derived_from:
  - compose/docker-compose.base.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Verify MongoDB state

## Goal

Confirm the main `mongo` container is PRIMARY in its single-node replica set,
runs with the intended cache size and memory limit, and has not been
OOM-killed.

## Prerequisites

- [ ] A running deployment; `<PREFIX>` is the `PROJECT_PREFIX` setting if one is set (container name `<PREFIX>mongo`).

## Steps

1. Replica set state (expect `1`, PRIMARY):

   ```bash
   docker exec <PREFIX>mongo mongo --quiet --eval 'rs.status().myState'
   ```

2. Effective WiredTiger cache in bytes:

   ```bash
   docker exec <PREFIX>mongo mongo --quiet --eval 'db.serverStatus().wiredTiger.cache["maximum bytes configured"]'
   ```

3. Memory usage against the limit, and whether the limit ever killed it:

   ```bash
   docker stats --no-stream <PREFIX>mongo
   docker inspect --format '{{.State.OOMKilled}}' <PREFIX>mongo
   ```

## Verify

`myState` is `1`; the cache equals `MONGO_WIREDTIGER_CACHE_GB` in bytes; usage
stays under `MONGO_MEMORY_LIMIT`; `OOMKilled` is `false`. `dbserver` and
`data_interconnector` logs show no reconnect loops.

## Rollback

Not applicable.

## Related

- [MongoDB deployment settings](../reference/mongodb.md)
- [Tune MongoDB performance](tune-mongodb-performance.md)
