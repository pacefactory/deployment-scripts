---
title: "Web browsers and API clients"
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
last_verified: 2026-09-10
verified_against: ba84b53
---

# Web browsers and API clients

## What it connects to

People using the web UIs and scripts calling the HTTP APIs from the site
network or, with an `https-*` profile, from wherever the site exposes the
host.

## Which Pacefactory services participate, and via which profile(s)

Published host ports, from the fragments (defaults shown). Several are
planned to disappear; see the linked issues.

| Host port | Service | Profile | Purpose | Status |
|---|---|---|---|---|
| `HTTP_PORT` 80 | apigateway | base | all web UIs and `/api/*`; 307 redirect to HTTPS when an `https-*` profile is enabled | current |
| `HTTPS_PORT` 443 | apigateway | any `https-*` | TLS entry point | current |
| `SOCIAL_VIDEO_PUBLIC_PORT` 9999 | social_video_server | social | video streams | to be removed, [#204](https://github.com/pacefactory/deployment-scripts/issues/204) |
| `RDB_PUBLIC_PORT` 8282 | relational_dbserver | rdb | direct API | to be removed, [#204](https://github.com/pacefactory/deployment-scripts/issues/204) |
| `NODERED_PORT` 1880 | nodered | node-red | Node-RED editor and HTTP nodes | to be removed, [#204](https://github.com/pacefactory/deployment-scripts/issues/204) |
| `NTFY_PUBLIC_PORT` 333 | ntfy | ntfy | push server | deprecated, [#203](https://github.com/pacefactory/deployment-scripts/issues/203) |
| `SWIFT_LABELER_PUBLIC_PORT` 7474 | swift-labeler | swift-labeler | labelling UI | to be removed, [#204](https://github.com/pacefactory/deployment-scripts/issues/204) |
| `GIFWRAPPER_PUBLIC_PORT` 7171, `DTREESERVER_PUBLIC_PORT` 7272 | service_gifwrapper, service_dtreeserver | service-ports | utility interfaces | profile to be dropped, [#205](https://github.com/pacefactory/deployment-scripts/issues/205) |
| ephemeral → 5380, 5381 | alert_processing_engine, ape_frame_playback | ape | direct API and playback | under investigation, [#206](https://github.com/pacefactory/deployment-scripts/issues/206) |
| `127.0.0.1:PERF_EVAL_HTTP_PORT` 3006 → 3005 | service_audit_processing_perf_eval | audit-perf-eval | loopback-only metrics | current (benchmark only) |
| `PF_MOSQUITTO_PUBLIC_PORT` 1883, `MQTTS_PUBLIC_PORT` 8883 | pf_mosquitto | mqtt-public, mqtts-public | see [mqtt-clients](mqtt-clients.md) | current |

## Direction and protocol(s)

Inbound HTTP/HTTPS. The apigateway adds no authentication of its own: no
`auth_*` directive exists in its templates
([route table](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/reference/api.md)). Authentication is per UI (Expresso UI password gate
via `EXPRESSO_UI_PASSWORD_PROTECTION`; `relational_dbserver` has none, and its
`/config` API returns database passwords in clear, see its
[API reference](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/reference/api.md);
others `TODO(source)` in their repos).

On the apigateway ports: plain HTTP on `HTTP_PORT`, where `/` answers a `302`
to `/scv3/` (or proxies the social web app when `social` is enabled); with an
`https-*` profile, HTTPS on `HTTPS_PORT` with TLS 1.2 and 1.3 and HTTP/2, a
`Content-Security-Policy: frame-ancestors 'none'` header, and a `307` from the
HTTP port to the HTTPS URL (carrying `:HTTPS_PORT` when it is not 443). Proxied
requests have no body-size limit and 3600 s read and send timeouts. Details
and sources: [apigateway listeners](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/reference/api.md#listeners).

## Client-side network requirements

Only 80/443 need to be reachable by users in the normal case; the other ports
are optional and go away with the issues above. See
[site requirements](../network/site-requirements.md).

## Payload summary

HTML, JSON APIs, video and image streams. Per-service API references live in
the owning repos (see [glossary](../glossary.md#services)).

## Failure modes at the boundary

Behind the apigateway a stopped or unreachable upstream returns
`502 Bad Gateway` for that path only; nginx resolves upstream names once at
configuration load, so a recreated upstream container keeps returning `502`
until `nginx -s reload`. `update.sh` issues that reload after every `up`
(`update.sh:120-121`). An upstream name that does not resolve when the gateway
starts stops nginx altogether (`host not found in upstream`), which is why
every `apigateway` block lists its upstreams under `depends_on`. Recovery:
[Recover from upstream errors](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/how-to/recover-from-upstream-errors.md). With an `https-*` profile and no
certificate files, the gateway serves a temporary self-signed certificate
rather than failing: [Replace the self-signed certificate](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/how-to/replace-the-self-signed-certificate.md).
Internals: [apigateway architecture](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/architecture/README.md).

## Variants

None.
