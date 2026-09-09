---
title: "ntfy subscribers"
type: reference
derived_from:
  - compose/docker-compose.ntfy.yml
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# ntfy subscribers

> **Deprecated.** ntfy is being removed from the deployment and from these docs;
> tracked in [#203](https://github.com/pacefactory/deployment-scripts/issues/203).

## What it connects to

Phones and desktops running an ntfy client, subscribing to topics on the
deployment's own `ntfy` server.

## Which Pacefactory services participate, and via which profile(s)

- `ntfy` (profile `ntfy`, default off): `binwiederhier/ntfy` serving on
  container port 80, published as `NTFY_PUBLIC_PORT` (default 333)
  (`compose/docker-compose.ntfy.yml:24-25`). No Pacefactory service in any
  fragment is configured to publish to it; `TODO(source)`: which service
  produces notifications (Node-RED flows are the likely producer).

## Direction and protocol(s)

Inbound HTTP on the published port for both publishing and subscribing.
`TODO(source)`: whether the server also pushes upstream to ntfy.sh, APNs or
FCM (not configured in the fragment).

## Client-side network requirements

Subscribers must reach the host on `NTFY_PUBLIC_PORT`. See [site requirements](../network/site-requirements.md).

## Payload summary

ntfy messages: <https://docs.ntfy.sh/publish/>.

## Failure modes at the boundary

`TODO(source)`.

## Variants

None.
