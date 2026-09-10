---
title: "Client SQL database"
type: reference
derived_from:
  - compose/docker-compose.rdb.yml
  - scripts/docs/flows.tsv
  - scripts/docs/externals.tsv
last_verified: 2026-09-10
verified_against: ba84b53
---

# Client SQL database

## What it connects to

A client's existing relational database: Microsoft SQL Server or PostgreSQL.
The `rdb` fragment describes the service as enabling "integrations between
the webgui and a client's existing SQL database"
(`compose/docker-compose.rdb.yml:5-7`). The two engines are the only ones
whose drivers the service image ships; see the service's
[connection config reference](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/reference/schemas/connection-config.md).

## Which Pacefactory services participate, and via which profile(s)

- `relational_dbserver` (profile `rdb`, default on;
  [architecture](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/architecture/README.md))
  is the only service that talks to the client database. It is reached
  internally by `apigateway` (`/api/rdb`, also carrying browser calls from
  `auditgui` via `WEBGUI_RDB_URL`), `service_audit_processing` and
  `expresso_server` on port 8282 (`compose/docker-compose.rdb.yml:29-47`),
  and directly on host port `RDB_PUBLIC_PORT` (`:22-23`).

## Direction and protocol(s)

Outbound from the deployment. `relational_dbserver` opens the connection on
the first request that needs a database and sends the SQL statement
configured for the requested route; the rows come back on the same
connection. Nothing in the deployment listens for the client database.

| Attribute | Value | Source |
|---|---|---|
| Wire protocol | TDS for SQL Server (`type: mssql`), PostgreSQL wire protocol for PostgreSQL (`type: postgres`); chosen per database | service repo `package.json` (drivers `mssql`, `pg`), [connection-config](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/reference/schemas/connection-config.md) |
| Host and port | Per database, from `db/<database>/connection.json` on the `relational_dbserver-data` volume; the committed examples use 1433 and 5432 | `compose/docker-compose.rdb.yml:24-25`; [config-tree](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/reference/schemas/config-tree.md) |
| Authentication | Username and password stored in clear text in `connection.json` | [connection-config](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/reference/schemas/connection-config.md) |
| TLS | Driver options passed through unchanged (`options.encrypt`, `options.trustServerCertificate` in the SQL Server example); no TLS handling of its own | same |
| Configuration | Not in compose: no fragment variable names the client database. It is loaded onto the volume or written through the service's `/config` API | [add a database and route](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/how-to/add-a-database-and-route.md) |

## Client-side network requirements

The deployment host must be allowed to open TCP connections to the client
database host and port (1433 or 5432 unless the site uses another port).
Nothing needs to reach the deployment for this integration.
`relational_dbserver` also publishes host port `RDB_PUBLIC_PORT` (default
8282) for direct, unauthenticated API access (`compose/docker-compose.rdb.yml:22-23`);
see [web clients](web-clients.md) and
[site requirements](../network/site-requirements.md).

## Payload summary

One parameterised SQL statement per request, taken from the route's JSON
file, with URL parameters bound positionally or concatenated into the text;
every committed example is a `SELECT`. The result rows are returned to the
caller unchanged as JSON. Statement and parameter rules:
[get-route-config](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/reference/schemas/get-route-config.md).

## Failure modes at the boundary

When the client database is unreachable or rejects the login,
`relational_dbserver` rebuilds its configuration from disk, retries the
connection once, and answers the caller with HTTP `400` and an error object
(`connected: false`); it retries again on every later request, so the route
recovers by itself once the database is reachable. Nothing is queued or
cached. The service has no health endpoint, so the failure is visible only in
its log and in the callers' responses. Details and recovery:
[recover from a failed database connection](https://github.com/pacefactory/scv2_relational_dbserver/blob/main/docs/how-to/recover-from-a-failed-database-connection.md).

## Variants

- SQL Server (`mssql`) and PostgreSQL (`postgres`), selected by the
  `type` field of each `connection.json`; per-engine options are documented
  in the service repo, not here.
- `TODO(source)`: no site-specific variant (other engines, ODBC, read
  replicas) is evidenced in either repository.
