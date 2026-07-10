# MongoDB Deployment Notes

This document covers how the main `mongo` service (used by `dbserver` and
`data_interconnector`) is deployed, why its memory is bounded, and why it runs
as a **single-node replica set**.

## Background

Deployments previously ran `mongod` with no memory bounds. MongoDB sizes its
WiredTiger cache to roughly 50% of RAM, and **mongod 4.2 cannot detect
container (cgroup v2) memory limits**, so it sizes the cache from the *host*
RAM. Combined with allocator fragmentation (a known issue with the tcmalloc
bundled in the 4.x series), memory use grows over time until the host OOM
killer SIGKILLs mongod. An unclean kill discards any writes that were
acknowledged but not yet journaled/checkpointed, which has caused data loss.

The mitigations are layered:

1. **Bound the WiredTiger cache** (`--wiredTigerCacheSizeGB`) so mongod's main
   memory consumer has an explicit ceiling.
2. **Bound the container** (`deploy.resources.limits.memory`) so that even
   with fragmentation/overhead growth, the kernel kills and docker restarts
   *only* the mongo container (`restart: always`) instead of the host OOM
   killer picking arbitrary victims.
3. **Run as a single-node replica set** so clients can request
   journal-acknowledged writes, making acknowledged data survive an unclean
   mongod death (see below).

## Settings

These are prompted by `./build.sh` and stored in `.env`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `MONGO_MEMORY_LIMIT` | `3g` | Hard memory limit for the mongo container. **Must include units** (e.g. `3g`, `4096m`). |
| `MONGO_WIREDTIGER_CACHE_GB` | `1` | WiredTiger cache size in GB (fractional values allowed, min `0.25`). |
| `MONGO_OPLOG_SIZE_MB` | `2048` | Maximum oplog size in MB (replica set write-ahead log, capped collection on disk). |

### Sizing guidance

Use MongoDB's own rule: WiredTiger cache should be at most
**50% of (memory limit − 1 GB)**. The rest of the budget is used by
connections, in-memory sorts/aggregations, the oplog and allocator overhead.

| Host RAM | Suggested `MONGO_MEMORY_LIMIT` | Suggested `MONGO_WIREDTIGER_CACHE_GB` |
| --- | --- | --- |
| 8 GB | `2g` | `0.5` |
| 16 GB | `3g` (default) | `1` (default) |
| 32 GB | `6g` | `2.5` |
| 64 GB+ | `12g` | `5.5` |

A smaller cache trades query performance for stability; data is never lost by
shrinking the cache, mongod just reads from disk more often. If the container
is observed restarting due to the memory limit (`docker inspect mongo`
shows `OOMKilled: true`), raise `MONGO_MEMORY_LIMIT` rather than the cache.

Host swap also matters: with a container memory limit set, docker allows the
container to swap by default, which smooths out short spikes instead of
killing the process. Keep a swap partition/file enabled on database hosts.

## Single-node replica set

The `mongo` service runs with `--replSet rs0`. A replica set with one member
provides no redundancy, but it changes *durability and capability semantics*:

- **Crash-durable acknowledgements**: replica set members journal writes
  before acknowledging when clients ask for it (`j: true` / majority write
  concern). `dbserver` and `data_interconnector` now request
  journal-acknowledged writes by default, so an acknowledged insert survives
  an OOM kill or power loss (at worst, mongod replays the journal on restart).
- **Retryable writes**: drivers can safely retry interrupted writes exactly
  once (enabled by default in modern pymongo, but only functional against
  replica sets). This covers the window where mongo is being restarted.
- **Change streams**: services can subscribe to data changes via the oplog
  instead of polling. Not used yet, but this unblocks it.
- **Transactions**: multi-document transactions require a replica set.
- **Oplog as a recovery aid**: the oplog is an on-disk log of recent writes
  which can help diagnose/replay recent activity after an incident.

Costs: every write is additionally written to the oplog (bounded by
`MONGO_OPLOG_SIZE_MB`, default 2 GB of disk) and journal-acknowledged writes
are slightly slower than fire-and-forget writes. This is the right trade for
metadata we do not want to lose.

### How initialization works

The replica set is initialized automatically — no manual step is required.
The mongo container healthcheck:

1. Reports healthy only when the node is `PRIMARY`.
2. On a fresh (or pre-existing standalone) data volume, `rs.status()` returns
   `NotYetInitialized` (code 94) and the healthcheck runs `rs.initiate()` with
   the container's own hostname. The node elects itself PRIMARY within a few
   seconds.
3. If the container hostname ever changes (e.g. the `PROJECT_PREFIX` setting
   changes while reusing the same data volume), the node would come up
   `REMOVED` (`InvalidReplicaSetConfig`, code 93); the healthcheck self-heals
   by force-reconfiguring the replica set to the new hostname.

Existing deployments upgrade in place: on the first `./update.sh` with this
configuration, mongod starts with the existing data files, the healthcheck
initiates the replica set, and all data remains intact. Expect roughly 10-30
seconds of write unavailability while the node initiates on first boot;
`dbserver` and `data_interconnector` already retry their connections.

### Verifying

```bash
# Replica set state (expect "myState": 1, i.e. PRIMARY)
docker exec mongo mongo --quiet --eval 'rs.status().myState'

# Effective WiredTiger cache size (bytes)
docker exec mongo mongo --quiet --eval 'db.serverStatus().wiredTiger.cache["maximum bytes configured"]'

# Container memory usage vs limit
docker stats --no-stream mongo

# Whether the container has ever been killed by its memory limit
docker inspect --format '{{.State.OOMKilled}}' mongo
```

(Prefix the container name with your `PROJECT_PREFIX` if one is set.)

### Diagnosing slow writes / slow batch processing

If batch processing (`service_audit_processing`) or ingest slows down after
this configuration lands, run the read-only diagnostic script on the affected
server and compare the highlighted numbers against the notes it prints:

```bash
./scripts/diagnose_mongo_slowdown.sh [project_prefix]
```

The three mechanisms this configuration can slow down, and the isolation knob
for each (change ONE at a time, re-measure batch run duration after each):

1. **WiredTiger cache too small** (cache miss ratio > ~5%, large
   "application threads page read from disk" deltas). Before this change the
   cache was ~50% of *host* RAM; the default is now a flat 1 GB. Raise the
   cache without restarting mongod (takes effect immediately, lasts until the
   next restart):

   ```bash
   docker exec mongo mongo --quiet --eval 'db.adminCommand({setParameter: 1, wiredTigerEngineRuntimeConfig: "cache_size=4G"})'
   ```

   If this fixes it, make it permanent by raising `MONGO_WIREDTIGER_CACHE_GB`
   (and `MONGO_MEMORY_LIMIT` to at least double the cache) in `.env` /
   `./build.sh`, then `./update.sh`.

2. **Journal-acknowledged writes** (high journal syncs/s with high
   time-in-sync, mean write latency > ~10 ms, especially on spinning disks).
   Disable in the clients only — no mongo change needed: add
   `MONGO_JOURNALED_WRITES=false` to the `dbserver` environment and
   `PF_MONGO_JOURNALED_WRITES=false` to the `data_interconnector` environment,
   then recreate those two containers.

3. **Oplog write amplification / memory-limit swapping** (high oplog churn
   MB/hour relative to disk speed, or the mongo container swapping /
   OOMKilled / RestartCount climbing). Raise `MONGO_MEMORY_LIMIT`, and if the
   oplog churn itself is the problem, roll back the replica set entirely
   (below).

### Rolling back

To return to a standalone mongod: remove `--replSet rs0` and `--oplogSize ...`
from the `command` and the `healthcheck` block in
`compose/docker-compose.base.yml`, rebuild (`./build.sh -q`) and re-run
`./update.sh`. mongod starts fine on the same data volume (the leftover
replica set config in the `local` database is ignored, and can optionally be
cleaned by dropping the `local` database). If journal-acknowledged writes are
kept enabled in the clients they continue to work against a standalone node.

## Related client behaviour

- `scv2_dbserver` connects with `journal=True` (journal-acknowledged writes)
  and `directConnection=True` by default; both are overridable via the
  `MONGO_JOURNALED_WRITES` / `MONGO_DIRECT_CONNECTION` env vars.
- `data_interconnector` (the MQTT → mongo ingest path) does the same via
  `PF_MONGO_JOURNALED_WRITES` / `PF_MONGO_DIRECT_CONNECTION`.
- `scv2_realtime` does not talk to mongo directly (it goes through dbserver's
  HTTP API) and needs no configuration.

`directConnection=True` makes clients talk to the configured host directly
instead of relying on replica-set topology discovery. This keeps single-node
behaviour identical to the old standalone behaviour regardless of hostname or
`PROJECT_PREFIX` changes, and also works for host-based development against a
port-published mongo.

## Known gaps / future work

- **The `autozone_mongo` (mongo 7.0) and `mongo_exp` (mongo 8.x) services are
  not yet memory-bounded.** Modern mongod detects cgroup limits and sizes its
  cache accordingly, so adding a `deploy.resources.limits.memory` to those
  services is sufficient when needed.
- The main image is `mongo:4.2.3` (EOL). Newer server versions have a better
  allocator and native container-awareness, but upgrading requires stepping
  through major versions (4.2 → 4.4 → 5.0 → ...) with
  `featureCompatibilityVersion` bumps on every deployed data volume — a
  separate, carefully staged project.
