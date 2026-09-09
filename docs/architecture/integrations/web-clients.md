---
title: Web browsers, API clients and the host filesystem
type: reference
derived_from:
  - compose/docker-compose.ape.yml
  - compose/docker-compose.audit-perf-eval.yml
  - compose/docker-compose.autozone.yml
  - compose/docker-compose.base.yml
  - compose/docker-compose.cuda.yml
  - compose/docker-compose.expresso-010.yml
  - compose/docker-compose.expresso-020-cuda.yml
  - compose/docker-compose.expresso-030-trainer.yml
  - compose/docker-compose.https-digitalocean.yml
  - compose/docker-compose.https-godaddy.yml
  - compose/docker-compose.https-manual.yml
  - compose/docker-compose.https-no-certbot.yml
  - compose/docker-compose.mqtt-public.yml
  - compose/docker-compose.mqtts-public.yml
  - compose/docker-compose.node-red.yml
  - compose/docker-compose.ntfy.yml
  - compose/docker-compose.offline.yml
  - compose/docker-compose.rdb.yml
  - compose/docker-compose.service-ports.yml
  - compose/docker-compose.social.yml
  - compose/docker-compose.swift-labeler.yml
  - compose/docker-compose.tools.yml
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# Web browsers, API clients and the host filesystem

## What it connects to

- `ext_web_clients`: people using the web UIs and scripts calling the HTTP
  APIs, from the site network or, with an `https-*` profile, the internet.
- `ext_host_fs`: the deployment host's own filesystem, where bind mounts
  bring credentials, CLI scripts and recorded video in and out of containers.

## Which Pacefactory services participate, and via which profile(s)

Published host ports, from the fragments (defaults shown):

| Host port | Service | Profile | Purpose |
|---|---|---|---|
| `HTTP_PORT` 80 | apigateway | base | all web UIs and `/api/*`; 307 redirect to HTTPS when an `https-*` profile is enabled |
| `HTTPS_PORT` 443 | apigateway | any `https-*` | TLS entry point |
| `SOCIAL_VIDEO_PUBLIC_PORT` 9999 | social_video_server | social | video streams |
| `RDB_PUBLIC_PORT` 8282 | relational_dbserver | rdb | direct API |
| `NODERED_PORT` 1880 | nodered | node-red | Node-RED editor and HTTP nodes |
| `NTFY_PUBLIC_PORT` 333 | ntfy | ntfy | push server (see [push-clients](push-clients.md)) |
| `SWIFT_LABELER_PUBLIC_PORT` 7474 | swift-labeler | swift-labeler | labelling UI |
| `GIFWRAPPER_PUBLIC_PORT` 7171, `DTREESERVER_PUBLIC_PORT` 7272 | service_gifwrapper, service_dtreeserver | service-ports | utility interfaces |
| ephemeral → 5380, 5381 | alert_processing_engine, ape_frame_playback | ape | direct API and playback |
| `127.0.0.1:PERF_EVAL_HTTP_PORT` 3006 → 3005 | service_audit_processing_perf_eval | audit-perf-eval | loopback-only metrics |
| `PF_MOSQUITTO_PUBLIC_PORT` 1883, `MQTTS_PUBLIC_PORT` 8883 | pf_mosquitto | mqtt-public, mqtts-public | see [mqtt-clients](mqtt-clients.md) |

Bind mounts (`ext_host_fs`):

| Host path (canonical checkout) | Container | Profile | Mode |
|---|---|---|---|
| `record_cli.py`, `stitch_cli.py` | record_video, stitch_videos | tools | rw |
| `~/scv2/videos` | record_video, stitch_videos | tools | rw |
| `credentials/digitalocean`, `credentials/godaddy` | certbot | https-digitalocean, https-godaddy | ro |
| `credentials/ssl` | apigateway, pf_mosquitto | https-no-certbot (+ mqtts-public) | ro |

## Direction and protocol(s)

Inbound HTTP/HTTPS for web clients; file access for the host filesystem.
Authentication is per UI (Expresso UI password gate via
`EXPRESSO_UI_PASSWORD_PROTECTION`; others `TODO(source)` in their repos).

## Client-side network requirements

Only 80/443 need to be reachable by users in the normal case; the other ports
are optional and can be disabled by not enabling their profile. See
[site requirements](../network/site-requirements.md).

## Payload summary

HTML, JSON APIs, video and image streams. Per-service API references live in
the owning repos (see [glossary](../glossary.md#services)).

## Failure modes at the boundary

Behind the apigateway a stopped upstream returns nginx errors; `update.sh`
reloads nginx after `up` to refresh upstream DNS (`update.sh:120-121`).

## Variants

None.
