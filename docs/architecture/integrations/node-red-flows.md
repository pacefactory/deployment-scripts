---
title: "Node-RED flow endpoints"
type: reference
derived_from:
  - compose/docker-compose.node-red.yml
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# Node-RED flow endpoints

## What it connects to

Whatever a site's Node-RED flows are configured to talk to. Node-RED is a
general integration engine; its external endpoints are runtime configuration
stored on the `nodered-data` volume, not in any fragment.

## Which Pacefactory services participate, and via which profile(s)

- `nodered` (profile `node-red`, default on): `nodered/node-red:4.0.5-22`,
  editor and HTTP nodes on host port `NODERED_PORT` (default 1880), also
  proxied by the apigateway (`compose/docker-compose.node-red.yml`). Receives
  `SITE_NAME` from `NODERED_SITE_NAME`.

## Direction and protocol(s)

Bidirectional, protocol varies per flow. Inside the deployment, flows most
plausibly consume `pf_mosquitto` (same `external_network`) but no fragment
evidences it: `TODO(source)` (flow exports per site).

## Client-side network requirements

Per site. Record the flows' external endpoints in the site's own runbook.

## Payload summary

Per flow. `TODO(source)`.

## Failure modes at the boundary

Per flow. `TODO(source)`.

## Variants

Per site.
