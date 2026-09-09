---
title: Record and stitch camera video
type: how-to
derived_from:
  - compose/docker-compose.tools.yml
  - record_cli.py
  - stitch_cli.py
last_verified: 2026-09-09
verified_against: ccf3768
---

# Record and stitch camera video

## Goal

Record a raw RTSP stream from one camera to the host, then stitch a day's
segments into one file per camera.

## Prerequisites

- [ ] A running deployment (the `tools` profile is always built).
- [ ] `<CAMERA_ID>` as defined in the realtime configuration (the `realtime-data` volume).
- [ ] `<DURATION>` in seconds (`300`) or shorthand (`10m`, `1h`, `2.5d`).
- [ ] `<DATE>` folder name `YYYY-MM-DD`, or an absolute path to a date folder.
- [ ] Output root `~/scv2/videos` on the host, taken from `${HOME}` when the compose file was built (`compose/docker-compose.tools.yml:23,42`).

## Steps

1. Record, detached so long recordings do not block the terminal:

   ```bash
   docker compose run -d --rm record_video <CAMERA_ID> <DURATION>
   ```

   Segments land in `~/scv2/videos/<YYYY-MM-DD>/<CAMERA_ID>/` and are made
   world-writable so the host user can delete them (`record_cli.py`).

2. Stitch every camera folder under a date; source directories are deleted
   unless `--keep-source` is passed:

   ```bash
   docker compose run --rm stitch_videos <DATE> [--keep-source]
   ```

   Output: `~/scv2/videos/<YYYY-MM-DD>/<CAMERA_ID>-<DATE>.mp4`. The
   `stitch_videos` container has `network_mode: none`.

## Verify

```bash
ls -l ~/scv2/videos/<DATE>/
ffprobe ~/scv2/videos/<DATE>/<CAMERA_ID>-<DATE>.mp4
```

## Rollback

Not applicable; pass `--keep-source` if you need to re-stitch.

## Related

- [IP cameras integration](../architecture/integrations/cameras-rtsp.md)
- [`tools` profile](../architecture/profiles/tools.md)
