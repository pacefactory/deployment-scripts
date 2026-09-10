---
title: "MQTT clients"
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.mqtt-public.yml
  - compose/docker-compose.mqtts-public.yml
  - compose/docker-compose.expresso-010.yml
  - compose/docker-compose.ape.yml
  - scripts/docs/flows.tsv
last_verified: 2026-09-10
verified_against: 794523d
---

# MQTT clients

## What it connects to

Third-party MQTT consumers and publishers at the site (dashboards, PLC
gateways, integration middleware, Node-RED flows). The deployment **provides**
the broker (`pf_mosquitto`, profile `base`); external systems are clients of
it. No fragment configures a connection to an external broker, and the broker
image makes no outbound connections
([pf_mosquitto architecture](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/architecture/README.md)).

## Which Pacefactory services participate, and via which profile(s)

- `pf_mosquitto` (base): the broker. Three listeners exist in the image:
  plain MQTT 1883, MQTT over WebSocket 7575, and MQTTS 8883 which the image
  opens only when certificate files are mounted
  ([pf_mosquitto configuration reference](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/reference/configuration.md)).
- `mqtt-public` (sub-profile of base, default on): publishes 1883 on the host
  (`compose/docker-compose.mqtt-public.yml:16-18`).
- `mqtts-public` (sub-profile of every `https-*`, default on): publishes 8883,
  mounts the https-* certificate at `/etc/mosquitto-tls` and passes
  `SERVER_NAME` (`compose/docker-compose.mqtts-public.yml:18-24`).
- `apigateway` (base): proxies the WebSocket listener at `/api/mqtt`
  (`compose/docker-compose.base.yml:359-361`); the Expresso UI and web GUI use it
  from the browser (`compose/docker-compose.expresso-010.yml:131-139`).
- Internal publishers and subscribers (realtime, data_interconnector,
  service_audit_processing, celery_worker, alert_processing_engine,
  ape_frame_playback) connect over the docker network; their rows are in the
  [`base`](../profiles/base.md), [`expresso-010`](../profiles/expresso-010.md)
  and [`ape`](../profiles/ape.md) profile pages.

## Direction and protocol(s)

Inbound. `MQTT` on host port `PF_MOSQUITTO_PUBLIC_PORT` (default 1883);
`MQTTS` on `MQTTS_PUBLIC_PORT` (default 8883) with the same certificate the
apigateway serves; `WS` behind the gateway on 80/443.

Authentication is username/password against the broker's password file, with
anonymous connections allowed and restricted by the broker's ACL: any client,
authenticated or not, may subscribe to every topic; only the `admin` user may
publish. There is no client-certificate authentication on the TLS listener.
The `admin` password is baked into the pf_mosquitto image and repeated
literally in this repository by the healthcheck
(`compose/docker-compose.base.yml:182-185`) and the alert-processing fragments
(`compose/docker-compose.ape.yml:32,58`). Rotate it per site with the
pf_mosquitto how-to
[Rotate the admin password](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/how-to/rotate-the-admin-password.md)
and update those fragments in the same change; the credential and ACL details
are in the pf_mosquitto
[configuration reference](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/reference/configuration.md).
Listener publication per profile: [MQTT broker listeners](../../reference/mqtt-broker-listeners.md).

## Client-side network requirements

Open host ports 1883 and/or 8883 to the clients that need them. See
[site requirements](../network/site-requirements.md).

## Payload summary

The broker defines no topics and no message formats; every payload belongs to
the service that publishes it. Real-time object data from realtime, segment
exports from audit processing, site-reliability snapshots from celery_worker,
alerts and debug messages from the alert processing engine: topic layout and
message schemas live in those services' repositories, linked from the
`Details` column of their rows in the profile pages above.

One payload originates in this repository: the broker's container healthcheck
publishes the message `ok` to the topic `healthcheck/ping` as `admin` from
inside the `pf_mosquitto` container every 10 seconds
(`compose/docker-compose.base.yml:173-189`). It is a loopback flow on the
container's own port 1883 and is visible to every subscriber of `#`. See
[container health checks](../../reference/container-healthchecks.md).

## Failure modes at the boundary

Documented by pf_mosquitto from its entrypoint; summary:

- If `SERVER_NAME` is unset, or `fullchain.pem` / `privkey.pem` are missing
  under `/etc/mosquitto-tls/live/<SERVER_NAME>/`, or the key cannot be
  decrypted with `privkey.pass`, the broker logs one line and starts with the
  1883 and 7575 listeners only. Nothing listens on 8883 and the container is
  still healthy, because the healthcheck uses 1883. Recovery:
  [Recover the MQTTS listener](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/how-to/recover-the-mqtts-listener.md).
- Renewed certificate files are picked up only on container restart.
- A stopped broker refuses every client. The internal services that list it
  under `depends_on` (`base`, `expresso-010` and `ape` fragments) are only
  ordered after it at start; none waits for it to be healthy. Their
  reconnection behaviour is documented in their own repositories.
- The `mosquitto-data` volume holds the persistence database and the
  password, ACL and `mosquitto.conf` files; removing it resets retained
  messages and credentials to the image defaults
  ([pf_mosquitto architecture: persistence](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/architecture/README.md#persistence-and-the-mosquitto-volume)).

## Variants

None in this repository.
