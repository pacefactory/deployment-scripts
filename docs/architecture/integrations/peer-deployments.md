---
title: "Peer Pacefactory deployments"
type: reference
derived_from:
  - compose/docker-compose.expresso-010.yml
  - .env.example
  - scripts/docs/flows.tsv
last_verified: 2026-09-10
verified_against: 9d0549a
---

# Peer Pacefactory deployments (remote training)

## What it connects to

Another Pacefactory deployment (typically at another site) that acts as a
remote trainer for Expresso, or that dispatches training to this one.

## Which Pacefactory services participate, and via which profile(s)

- `expresso_server` (profile `expresso-010`, forced) originates dispatch to
  peers listed in `PF_REMOTE_TRAINER_URLS` and receives callbacks at
  `<PF_EXPRESSO_PUBLIC_URL_BASE>/training/remote/callback`
  (`compose/docker-compose.expresso-010.yml:23-35, 84-91`).
- `apigateway` terminates the inbound callback at `/api/expresso/`, strips
  that prefix and proxies to `expresso_server:8456` with WebSocket upgrade
  headers passed through and no request-body limit
  ([apigateway route table](https://github.com/pacefactory/scv2_apigateway/blob/master/docs/reference/api.md)).

## Direction and protocol(s)

Bidirectional HTTPS between deployments. The URLs include scheme and the
`/api/expresso` prefix (for example `https://site.example.com/api/expresso`).
Leaving `PF_EXPRESSO_PUBLIC_URL_BASE` blank means this deployment cannot
originate remote training; local training still works. Authentication:
`TODO(source)` (expresso_server).

## Client-side network requirements

Each participating site must expose its apigateway HTTPS port to the peer
site and allow egress to the peer's URL. This implies an `https-*` profile on
both sides. See [site requirements](../network/site-requirements.md).

## Payload summary

Training job dispatch and completion callbacks. Schemas:
<https://github.com/pacefactory/expresso_server/blob/main/docs/architecture/README.md>.

## Failure modes at the boundary

`TODO(source)` (expresso_server).

## Variants

None.
