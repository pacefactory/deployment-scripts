---
title: MQTT clients
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.mqtt-public.yml
  - compose/docker-compose.mqtts-public.yml
  - compose/docker-compose.expresso-010.yml
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# MQTT clients

## What it connects to

Third-party MQTT consumers and publishers at the site (dashboards, PLC
gateways, integration middleware, Node-RED flows). The deployment **provides**
the broker (`pf_mosquitto`, profile `base`); external systems are clients of
it. No fragment configures a connection to an external broker.

## Which Pacefactory services participate, and via which profile(s)

- `pf_mosquitto` (base): the broker. Three listeners exist in the image:
  plain MQTT 1883, MQTTS 8883 and MQTT over WebSocket 7575
  (`compose/docker-compose.base.yml:359-361`, `README` of pf_mosquitto).
- `mqtt-public` (sub-profile of base, default on): publishes 1883 on the host
  (`compose/docker-compose.mqtt-public.yml:16-18`).
- `mqtts-public` (sub-profile of every `https-*`, default on): publishes 8883
  and mounts the https-* certificate (`compose/docker-compose.mqtts-public.yml:18-24`).
- `apigateway` (base): proxies the WebSocket listener at `/api/mqtt`
  (`compose/docker-compose.base.yml:359-361`); the Expresso UI and web GUI use it
  from the browser (`compose/docker-compose.expresso-010.yml:131-139`).

## Direction and protocol(s)

Inbound. `MQTT` on host port `PF_MOSQUITTO_PUBLIC_PORT` (default 1883);
`MQTTS` on `MQTTS_PUBLIC_PORT` (default 8883) with the same certificate the
apigateway serves; `WS` behind the gateway on 80/443. Authentication is
username/password; the healthcheck and the APE fragments use the default
`admin` account whose password is committed in this repository
(`compose/docker-compose.base.yml:183-185`, `compose/docker-compose.ape.yml:32`).
Rotate it per site; the mechanism is owned by pf_mosquitto.
Listener details: [MQTT broker listeners reference](../../reference/mqtt-broker-listeners.md).

## Client-side network requirements

Open host ports 1883 and/or 8883 to the clients that need them; internet-facing
sites should disable `mqtt-public` and use MQTTS only
(`compose/docker-compose.mqtt-public.yml:5-9`). See [site requirements](../network/site-requirements.md).

## Payload summary

Real-time object data from realtime, segment exports from audit processing,
site-reliability snapshots from celery_worker, alerts from APE. Topic layout
and message schemas: <https://github.com/pacefactory/pf_mosquitto/blob/main/docs/architecture/README.md>
and the publishing services' repos.

## Failure modes at the boundary

If the certificate files are missing at start, MQTTS is skipped and the broker
starts with 1883/7575 only (behaviour of the pf_mosquitto entrypoint, see
[MQTT broker listeners](../../reference/mqtt-broker-listeners.md)). Everything
else: `TODO(source)` in pf_mosquitto.

## Variants

None in this repository.
