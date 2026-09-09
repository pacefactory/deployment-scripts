---
title: Client SQL database
type: reference
derived_from:
  - compose/docker-compose.rdb.yml
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# Client SQL database

## What it connects to

A client's existing relational database. The `rdb` fragment describes the
service as enabling "integrations between the webgui and a client's existing
SQL database" (`compose/docker-compose.rdb.yml:5-7`).

## Which Pacefactory services participate, and via which profile(s)

- `relational_dbserver` (profile `rdb`, default on): the bridge service. It is
  reached internally by `apigateway` (`/api/rdb`), `service_audit_processing`
  and `expresso_server` on port 8282 (`compose/docker-compose.rdb.yml:29-47`).

## Direction and protocol(s)

Bidirectional from the deployment's point of view. `TODO(source)`: the
database engine, driver, port and how the connection is configured are not
visible in compose (no environment variable in the fragment names the client
database). They live in the relational-dbserver repo.

## Client-side network requirements

The deployment host must reach the client database host and port.
`relational_dbserver` also publishes host port `RDB_PUBLIC_PORT` (default 8282)
for direct API access (`compose/docker-compose.rdb.yml:22-23`).

## Payload summary

`TODO(source)`: <https://github.com/pacefactory/relational-dbserver/blob/main/docs/architecture/README.md>.

## Failure modes at the boundary

`TODO(source)`.

## Variants

`TODO`: per-engine specifics belong in the relational-dbserver repo.
