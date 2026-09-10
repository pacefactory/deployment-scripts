---
title: "Deployment host filesystem"
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
verified_against: 9d0549a
---

# Deployment host filesystem

## What it connects to

The deployment host's own filesystem, where bind mounts bring credentials,
CLI scripts and recorded video in and out of containers. Named volumes are
not part of this integration type; they are drawn as cylinders and documented
per reference deployment.

## Which Pacefactory services participate, and via which profile(s)

| Host path (canonical checkout `/home/pacefactory/scv2/git_clones/deployment-scripts`) | Container path | Service | Profile | Mode |
|---|---|---|---|---|
| `record_cli.py`, `stitch_cli.py` | `/home/scv2/record_cli.py`, `/home/scv2/stitch_cli.py` | record_video, stitch_videos | tools | rw |
| `~/scv2/videos` | `/output_videos` | record_video, stitch_videos | tools | rw |
| `credentials/digitalocean`, `credentials/godaddy` | `/opt/digitalocean/`, `/opt/godaddy/` | certbot | https-digitalocean, https-godaddy | ro |
| `credentials/ssl` | `/etc/nginx/ssl/` | apigateway | https-no-certbot | ro |
| `credentials/ssl` (via `MQTTS_CERT_SOURCE`) | `/etc/mosquitto-tls/` | pf_mosquitto | mqtts-public with https-no-certbot | ro |

Sources: `compose/docker-compose.tools.yml:21-23,40-42`,
`compose/docker-compose.https-digitalocean.yml:56`,
`compose/docker-compose.https-godaddy.yml:55`,
`compose/docker-compose.https-no-certbot.yml:33`,
`compose/docker-compose.mqtts-public.yml:22`.

## Direction and protocol(s)

File access (`file` in flow tables). Bind-mount sources are resolved to
absolute paths at build time, so the built compose file is specific to the
host that ran `build.sh`.

## Client-side network requirements

None. The host filesystem must hold the credential files before the
corresponding profile is launched ([Enable HTTPS](../../how-to/enable-https.md),
[Import a TLS certificate](../../how-to/import-ssl-certificate.md)).

## Payload summary

TLS certificates and keys, DNS API credentials, the two tool CLI scripts,
recorded video segments and stitched files.

## Failure modes at the boundary

Missing certificate files: the apigateway generates a self-signed
certificate for `SERVER_NAME` inside the container and serves that until the
files appear and the container is restarted
([Replace the self-signed certificate](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/how-to/replace-the-self-signed-certificate.md)); an encrypted key without
`privkey.pass` stops nginx at start
([apigateway configuration reference](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/reference/configuration.md#ssl-profile)). pf_mosquitto starts
without its MQTTS listener
([Recover the MQTTS listener](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/how-to/recover-the-mqtts-listener.md)).
Missing credentials files: certbot fails at start.

## Variants

None.
