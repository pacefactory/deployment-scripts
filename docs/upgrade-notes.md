---
title: Upgrade notes
type: other
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.audit-perf-eval.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Upgrade notes

Behaviour changes operators need to know about when pulling a new release.
Newest first.

## 2026-07: audit processing per-entry segment trimming

`PF_TRIM_SEGMENTS_TO_BLOCK` has been removed. Segment trimming at
processing-block boundaries is now controlled per entry in the audit config
(webgui, Advanced Entry Edit), is on by default for all station entries and
most generic entries, and trimmed pieces are stitched back together in
storage. A stale `PF_TRIM_SEGMENTS_TO_BLOCK` in an existing `.env` is harmless
(nothing interpolates it); re-run `./build.sh` to regenerate the compose file
without it.

New setting `PF_PROCESS_BLOCK_MAX_LOOKBACK_MINUTES` (default `240`,
`compose/docker-compose.base.yml:43-45`) caps the per-entry source-data
lookback that audit processing derives from each entry's duration parameters.

**Global kill switch.** The whole trim/stitch/derived-lookback feature is gated
by `PF_ENABLE_SEGMENT_TRIM_STITCH`, default `false`
(`compose/docker-compose.base.yml:46-48`), pending performance evaluation at
scale (see the [`audit-perf-eval` profile](architecture/profiles/audit-perf-eval.md)).
While false, audit processing behaves as before the feature landed and
per-entry trim settings are ignored; stored records are never modified by the
switch. Set it to `true` to enable the feature.

Segment data stored before this upgrade is left as-is: segments dropped or
trimmed under the old rules carry no provenance flags and are never touched by
the new stitching. Only blocks processed after the upgrade get the new
behaviour. Details: <https://github.com/pacefactory/scv3_services_processing>.

## Ghosting defaults

New deployments default to hard ghosting enforcement (`WEBGUI_FORCE_GHOSTING=true`,
`DBSERVER_DISABLE_SNAPSHOT_IMAGES=true`). Existing deployments that rely on
`WEBGUI_UNGHOSTED_CAMERA_LIST` must set `DBSERVER_DISABLE_SNAPSHOT_IMAGES=false`
to keep soft mode. See [Ghosting configuration](reference/ghosting.md).

## MongoDB memory bounding and replica set

Existing deployments upgrade in place: on the first `./update.sh` with the
bounded, `--replSet rs0` configuration, mongod starts on the existing data
files and the healthcheck initiates the replica set; expect 10 to 30 seconds
of write unavailability. See [MongoDB deployment settings](reference/mongodb.md).
