---
title: "IP cameras (RTSP)"
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.tools.yml
  - record_cli.py
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# IP cameras (RTSP)

## What it connects to

Site-installed IP cameras that serve a video stream over RTSP. Vendor and codec
are camera-specific; the deployment consumes the stream as-is.

## Which Pacefactory services participate, and via which profile(s)

- `realtime` (profile `base`): the camera ingest and real-time processing
  service. Camera configuration lives on the `realtime-data` volume at
  `/home/scv2/locations` (`compose/docker-compose.base.yml:238`).
- `record_video` (profile `tools`, on demand): reads the same configuration
  volume and records one camera's stream to the host (`record_cli.py:15,96-97`).

## Direction and protocol(s)

Inbound to the deployment. RTSP over **TCP only** (`record_cli.py:129` forces
`-rtsp_transport tcp`); the URL per camera is built from the location config
(`rtsp://…`, `record_cli.py:97`). Assume port 554, the RTSP default; 8554 is
the RTSP alternate port some cameras and relays use. Camera credentials are
part of the RTSP URL in the realtime configuration; their format is owned by
scv2_realtime. `TODO(source)`: realtime's own ingest path and reconnect
behaviour, and the preferred stream settings, are to be filled in from the
scv2_realtime docs.

## Client-side network requirements

The deployment host must reach every camera on TCP 554 (or 8554 where the camera uses the alternate port). Cameras do not need
to reach the host. No host port is published for this flow. See
[site requirements](../network/site-requirements.md).

## Payload summary

Compressed video (H.264/H.265 as served by the camera). Snapshot and object
metadata derived from it are written to dbserver over HTTP and published to
pf_mosquitto over MQTT (see the `base` [profile page](../profiles/base.md)).
Schemas: <https://github.com/pacefactory/scv2_realtime/blob/main/docs/architecture/README.md>.

## Failure modes at the boundary

`TODO(source)`: documented in scv2_realtime. `record_video` exits with an error
when it cannot build an RTSP URL (`record_cli.py:97-101`).

## Variants

`TODO`: per-vendor specifics belong in scv2_realtime.
