---
title: "MQTT broker listeners"
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.mqtt-public.yml
  - compose/docker-compose.mqtts-public.yml
  - compose/docker-compose.https-digitalocean.yml
  - compose/docker-compose.https-godaddy.yml
  - compose/docker-compose.https-manual.yml
  - compose/docker-compose.https-no-certbot.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# MQTT broker listeners

Which `pf_mosquitto` listeners are reachable from outside the docker network
depends on the build profiles enabled. The listener implementation (entrypoint,
TLS staging, credentials) is owned by
[pf_mosquitto](https://github.com/pacefactory/pf_mosquitto); this page covers
only what the fragments in this repository decide.

| Listener | Container port | Host port variable (default) | Published by | Default |
|---|---|---|---|---|
| MQTT | 1883 | `PF_MOSQUITTO_PUBLIC_PORT` (1883) | `mqtt-public`, sub-profile of `base` | enabled |
| MQTTS | 8883 | `MQTTS_PUBLIC_PORT` (8883) | `mqtts-public`, sub-profile of every `https-*` | enabled whenever an `https-*` profile is enabled |
| MQTT over WebSocket | 7575 | none (behind the apigateway at `/api/mqtt`) | `base` (`compose/docker-compose.base.yml:359-361`) | always |

## `mqtts-public` inputs

`mqtts-public` needs two values that only an `https-*` parent provides as hidden
settings (`compose/docker-compose.mqtts-public.yml:22-24`):

| Variable | `https-no-certbot` | `https-manual` | `https-godaddy` | `https-digitalocean` |
|---|---|---|---|---|
| `MQTTS_CERT_SOURCE` (mounted read-only at `/etc/mosquitto-tls/`; `:?` required) | `../credentials/ssl` | `certbot` | `certbot` | `certbot` |
| `MQTTS_FQDN_SUFFIX` (appended to `SERVER_NAME`) | unset | unset | `.pacefactory.com` | `.pacefactory.dev` |

The broker receives `SERVER_NAME=${SERVER_NAME}${MQTTS_FQDN_SUFFIX:-}` and is
expected to find `live/<SERVER_NAME>/{fullchain.pem,privkey.pem}` (optionally
`privkey.pass`) under the mount; if the files are missing it starts without the
MQTTS listener. Details: pf_mosquitto entrypoint (`TODO(source)`: link to its
configuration reference once published).

## Disabling a listener

- Plain MQTT: answer `n` to "Expose plain MQTT on port 1883?" during
  `./build.sh`, or set `[mqtt-public]="false"` in `.settings`.
- MQTTS: answer `n` to "Expose MQTTS on port 8883?", or set
  `[mqtts-public]="false"` in `.settings`.
- Set `MQTTS_PUBLIC_PORT` blank in `.env` to keep the TLS listener internal
  while leaving the profile on (`compose/docker-compose.mqtts-public.yml:14`).

## Client connection examples

```bash
# Plain
mosquitto_sub -h <SERVER> -p 1883 -u admin -P <PASSWORD> -t '#'

# TLS (MQTTS)
mosquitto_sub -h <SERVER> -p 8883 --capath /etc/ssl/certs -u admin -P <PASSWORD> -t '#'
```

The default `admin` password is committed in
`compose/docker-compose.base.yml:183-185` (healthcheck) and
`compose/docker-compose.ape.yml:32,58`; rotate it per site.
