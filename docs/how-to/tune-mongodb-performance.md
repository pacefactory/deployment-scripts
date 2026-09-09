---
title: Tune MongoDB performance
type: how-to
derived_from:
  - compose/docker-compose.base.yml
  - build.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Tune MongoDB performance

## Goal

Diagnose slow writes or slow batch processing after the memory-bounded,
replica-set configuration, and adjust one knob at a time.

## Prerequisites

- [ ] Symptoms: `service_audit_processing` block runs or ingest slower than before.
- [ ] Access to `docker exec` on the host; `<PREFIX>` as in [Verify MongoDB state](verify-mongodb.md).

## Steps

1. Sample the server status inside the container (`wiredTiger.cache`,
   `wiredTiger.log`, `opLatencies`), the slow-query log (`docker logs
   <PREFIX>mongo`, operations over `--slowms 200`), and container state
   (`docker stats`, `docker inspect` for `OOMKilled` and `RestartCount`),
   alongside host swap and disk utilisation.

2. Change ONE knob, re-measure the batch run duration, repeat:

   - **Cache too small** (cache miss ratio above about 5%, large "application
     threads page read from disk" deltas): raise the cache live, without a
     restart (lasts until the next restart):

     ```bash
     docker exec <PREFIX>mongo mongo --quiet --eval 'db.adminCommand({setParameter: 1, wiredTigerEngineRuntimeConfig: "cache_size=4G"})'
     ```

     If it helps, make it permanent: raise `MONGO_WIREDTIGER_CACHE_GB` in
     `.env` (and `MONGO_MEMORY_LIMIT` to at least double the cache), then
     `./build.sh -q && ./update.sh`.

   - **Journal-acknowledged writes** (high journal syncs per second with high
     time in sync, mean write latency above about 10 ms, spinning disks):
     disable in the clients only. The variables belong to the client services
     (`MONGO_JOURNALED_WRITES` in scv2_dbserver, `PF_MONGO_JOURNALED_WRITES` in
     data_interconnector); add them to those services' `environment` via a
     `compose/docker-compose.custom.yml` override and recreate the two
     containers.

   - **Oplog write amplification or swapping** (high oplog churn relative to
     disk speed, or the container swapping / `OOMKilled` / `RestartCount`
     climbing): raise `MONGO_MEMORY_LIMIT`; if the oplog itself is the problem,
     [roll back the replica set](roll-back-mongodb-replica-set.md).

## Verify

Batch run duration returns to the previous baseline; `OOMKilled` stays `false`
([Verify MongoDB state](verify-mongodb.md)).

## Rollback

Restore the previous `.env` values (`.env.backup`), `./build.sh -q`,
`./update.sh`.

## Related

- [MongoDB deployment settings](../reference/mongodb.md)
- [Design note](../design/mongodb-memory-bounding.md)
