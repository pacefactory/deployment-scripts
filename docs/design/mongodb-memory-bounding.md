---
title: "Design note: MongoDB memory bounding and single-node replica set"
type: other
derived_from:
  - compose/docker-compose.base.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Design note: MongoDB memory bounding and single-node replica set

Why the `base` fragment runs `mongo` with a memory limit, an explicit WiredTiger
cache size and `--replSet rs0`. The settings themselves are in the
[MongoDB reference](../reference/mongodb.md).

## Problem

Deployments previously ran `mongod` with no memory bounds. MongoDB sizes its
WiredTiger cache to roughly 50% of RAM, and mongod 4.2 cannot detect container
(cgroup v2) memory limits, so it sized the cache from the *host* RAM. Combined
with allocator fragmentation in the 4.x tcmalloc, memory use grew until the
host OOM killer killed mongod. An unclean kill discards acknowledged but
un-journaled writes, which caused data loss.

## Mitigations (layered)

1. **Bound the WiredTiger cache** (`--wiredTigerCacheSizeGB`) so the main
   memory consumer has an explicit ceiling.
2. **Bound the container** (`deploy.resources.limits.memory`) so that the
   kernel kills, and Docker restarts, only the mongo container instead of the
   host OOM killer picking arbitrary victims.
3. **Run as a single-node replica set** so clients can request
   journal-acknowledged writes.

## What a one-member replica set buys

No redundancy, but different durability and capability semantics:

- crash-durable acknowledgements when clients ask for `j: true` / majority
  write concern (dbserver and data_interconnector do);
- retryable writes, which cover the window while mongo restarts;
- change streams and multi-document transactions become available;
- the oplog is an on-disk log of recent writes that helps incident diagnosis.

Costs: every write also goes to the oplog (bounded by `MONGO_OPLOG_SIZE_MB`),
and journal-acknowledged writes are slightly slower than fire-and-forget.

## Trade-offs to keep in mind

- A smaller cache trades query performance for stability; data is never lost
  by shrinking the cache. If the container is OOM-killed, raise
  `MONGO_MEMORY_LIMIT`, not the cache.
- With a memory limit set, Docker allows the container to swap by default,
  which smooths short spikes. Keep swap enabled on database hosts.
- The original working set before bounding was about 50% of host RAM; sites
  with high camera counts or long report ranges may need to size up toward
  that, keeping the cache at 50% of (limit minus 1 GB).
