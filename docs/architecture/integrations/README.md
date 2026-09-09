---
title: Integration types
type: reference
derived_from:
  - scripts/docs/externals.tsv
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# Integration types

Every class of external system a Pacefactory deployment exchanges data with,
seeded from what the fragments and scripts in this repository evidence. IDs are
the `ext_*` node IDs used in every diagram; see the
[glossary](../glossary.md#external-integration-types). Each page follows the
skeleton in the [architecture standard §7a](../ARCHITECTURE_DOCS_STANDARD.md#7a-network-and-data-flow-inputsoutputs).

Types anticipated earlier (MES via REST, OPC) are not listed: no fragment or
script in this repository evidences them. Add a row to
`scripts/docs/externals.tsv` and a page here when a source appears.

| Integration type | ID | Protocol(s) | Direction | Participating services (profile) | Page |
|---|---|---|---|---|---|
| IP cameras | `ext_cameras` | RTSP | in | realtime (base), record_video (tools) | [cameras-rtsp.md](cameras-rtsp.md) |
| MQTT clients | `ext_mqtt_clients` | MQTT, MQTTS, WS | in | pf_mosquitto (mqtt-public, mqtts-public), apigateway `/api/mqtt` (base) | [mqtt-clients.md](mqtt-clients.md) |
| Client SQL database | `ext_client_sql` | SQL | bidi | relational_dbserver (rdb) | [client-sql.md](client-sql.md) |
| Let's Encrypt and DNS provider APIs | `ext_acme`, `ext_dns_api` | HTTPS | out | certbot (https-digitalocean, https-godaddy, https-manual) | [acme-dns.md](acme-dns.md) |
| Peer Pacefactory deployment | `ext_peer_deployment` | HTTPS | bidi | expresso_server, apigateway (expresso-010) | [peer-deployments.md](peer-deployments.md) |
| Container registry and GitHub | `ext_registry`, `ext_github` | HTTPS | out | host tooling: update.sh, runYq.sh, scripts/offline, scripts/remote | [registry-egress.md](registry-egress.md) |
| Web browsers and API clients; host filesystem | `ext_web_clients`, `ext_host_fs` | HTTP, HTTPS, file | in / bidi | apigateway and every service with a published port; bind mounts | [web-clients.md](web-clients.md) |
| ntfy subscribers | `ext_ntfy_clients` | HTTP | in | ntfy (ntfy) | [push-clients.md](push-clients.md) |
| Node-RED flow endpoints | `ext_nodered_endpoints` | varies | bidi | nodered (node-red) | [node-red-flows.md](node-red-flows.md) |
| Corporate proxy | `ext_proxy` | HTTP CONNECT | out | host shell (`~/connect-to-proxy.sh`) | [corporate-proxy.md](corporate-proxy.md) |
| Fleet operator workstation | `ext_fleet_operator` | SSH | in | host (`scripts/remote`) | [fleet-ssh.md](fleet-ssh.md) |
