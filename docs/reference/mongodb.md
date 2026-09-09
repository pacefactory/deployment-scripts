---
title: MongoDB deployment settings
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.audit-perf-eval.yml
  - compose/docker-compose.expresso-010.yml
  - compose/docker-compose.autozone.yml
  - build.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# MongoDB deployment settings

How the main `mongo` service (used by `dbserver` and `data_interconnector`) is
configured by the `base` fragment and `build.sh`. Why it is configured this
way is in the [design note](../design/mongodb-memory-bounding.md); procedures
are in [Verify MongoDB](../how-to/verify-mongodb.md),
[Tune MongoDB performance](../how-to/tune-mongodb-performance.md) and
[Roll back the MongoDB replica set](../how-to/roll-back-mongodb-replica-set.md).

## Image and command

`mongo:4.2.3-bionic`, started as
`mongod --quiet --slowms 200 --wiredTigerCacheSizeGB <cache> --replSet rs0 --oplogSize <MB>`
(`compose/docker-compose.base.yml:75,84-94`), with `ulimit nofile 64000`,
`logging: local`, a hard memory limit and `restart: always`.

## Settings

Prompted by `./build.sh` and stored in `.env`:

| Setting | Default | Meaning | Source |
|---|---|---|---|
| `MONGO_MEMORY_LIMIT` | scales with host RAM (below); `3g` if RAM cannot be read | Hard memory limit for the container. Must include units. | `base.yml:57-60,100` |
| `MONGO_WIREDTIGER_CACHE_GB` | scales with host RAM; `1` if RAM cannot be read | WiredTiger cache size in GB (fractional allowed). | `base.yml:61-64,90` |
| `MONGO_OPLOG_SIZE_MB` | `2048` | Maximum replica set oplog size in MB. | `base.yml:65-67,94` |

`build.sh` reads `/proc/meminfo` and exports the defaults (`build.sh:120-134`):

| Host RAM | `MONGO_MEMORY_LIMIT_DEFAULT` | `MONGO_WIREDTIGER_CACHE_GB_DEFAULT` |
|---|---|---|
| < 12 GB | `2g` | `0.5` |
| 12 to 23 GB | `4g` | `1.5` |
| 24 to 47 GB | `8g` | `3.5` |
| 48 GB and more | `16g` | `7` |

Explicit values in `.env` always win. To adopt the scaled defaults on an
existing deployment, delete the two lines from `.env` and re-run `./build.sh`
then `./update.sh`. Reference deployments pin `4g` / `1.5` so their output does
not depend on the building host.

Sizing rule (from the fragment descriptions): cache at most 50% of
(memory limit minus 1 GB).

## Single-node replica set

The healthcheck (`base.yml:106-129`) reports healthy only when the node is
`PRIMARY`, and as a side effect:

- on a fresh or previously standalone data volume (`rs.status()` code 94,
  `NotYetInitialized`) it runs `rs.initiate()` with the container's own
  hostname;
- if the hostname changed, for example after a `PROJECT_PREFIX` change (code
  93, `InvalidReplicaSetConfig`), it force-reconfigures the set to the new
  hostname.

Expect 10 to 30 seconds of write unavailability on first boot;
`start_period` is 90 s. Clients: `dbserver` and `data_interconnector` connect
with journal-acknowledged writes and direct connection by default; the
variables that control that are theirs
([scv2_dbserver](https://github.com/pacefactory/scv2_dbserver),
[data_interconnector](https://github.com/pacefactory/data_interconnector)) and are
not set by any fragment here.

## Other MongoDB instances

| Service | Image | Profile | Memory bounded? |
|---|---|---|---|
| `perf_eval_mongo` | `mongo:4.2.3-bionic` | audit-perf-eval | yes: `PERF_EVAL_MONGO_MEMORY_LIMIT` (`2g`), `PERF_EVAL_MONGO_WIREDTIGER_CACHE_GB` (`0.5`), oplog 512 MB |
| `mongo_exp` | `mongodb/mongodb-community-server:8.2.1-ubi8` | expresso-010 | no (`compose/docker-compose.expresso-010.yml:234-245`) |
| `autozone_mongo` | `mongo:7.0` | autozone | no (`compose/docker-compose.autozone.yml:46-56`) |

Modern mongod detects cgroup limits, so a `deploy.resources.limits.memory` on
the last two is sufficient when needed. The main image is 4.2 (end of life);
upgrading requires stepping through major versions with
`featureCompatibilityVersion` bumps on every deployed volume.
