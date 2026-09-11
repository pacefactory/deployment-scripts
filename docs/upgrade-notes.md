---
title: "Upgrade notes"
type: other
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.audit-perf-eval.yml
  - scripts/release/fetch-release.sh
  - scripts/remote/update-server.sh
  - .github/workflows/ci.yml
last_verified: 2026-09-11
verified_against: 8d85e22
---

# Upgrade notes

Behaviour changes operators need to know about when pulling a new release.
Newest first.

## 2026-09: deployment-scripts ships as a Docker Hub release image

The repository becomes private; servers no longer `git pull`. The scripts
tree is published as the file-only image `pacefactory/deployment-scripts`
(`.github/workflows/ci.yml`), fetched with the server's existing Docker Hub
login, and synced into `~/scv2/git_clones/deployment-scripts` by
`scripts/release/fetch-release.sh`. What changes for operators:

- **One-time migration per server.** Run
  `curl -fsSL https://get.pacefactory.dev/install.sh | bash` as the operating
  account. It converts the checkout in place; `.env`, `.settings`,
  `docker-compose.yml`, credentials and custom fragments are untouched. Paths
  that are not part of the release are removed from the server, `docs/`
  included; read the docs on GitHub. `.git` stays unless `PF_REMOVE_GIT=true`.
  See [Install or repair deployment-scripts on a server](how-to/install-deployment-scripts.md).
- **Routine updates.** `./scripts/release/fetch-release.sh` replaces
  `git pull --ff-only`; `./build.sh` and `./update.sh` are unchanged
  ([Update a deployment](how-to/update-a-deployment.md)). `git pull` on an
  unmigrated server fails with an authentication or repository-not-found error
  once the repository is private.
- **Versions.** `latest` follows `main` as `git pull` did; `vX.Y.Z` and
  `sha-<short>` tags pin or roll back (`PF_RELEASE=<tag>`). The installed
  release is in `.pf-release/VERSION`.
- **Fleet tooling.** `update-fleet.ps1` requires migrated servers and reports
  unmigrated ones as `NOT MIGRATED` (payload exit 17,
  `scripts/remote/update-server.sh:49-50`); run the one-liner on those first.
- **Credentials.** Servers must stay logged in to Docker Hub as `pacefactory`
  with their per-server token in `~/scv2/docker_oat.sh`; answer `n` to
  "Logout from DockerHub?" in `update.sh`.

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
