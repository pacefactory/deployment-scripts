---
title: "Container health checks"
type: reference
derived_from:
  - compose/docker-compose.base.yml
  - compose/docker-compose.ape.yml
  - compose/docker-compose.audit-perf-eval.yml
  - compose/docker-compose.tools.yml
  - compose/docker-compose.expresso-010.yml
  - compose/docker-compose.expresso-030-trainer.yml
last_verified: 2026-09-10
verified_against: 794523d
---

# Container health checks

Every `healthcheck:` a fragment attaches to a service, what the probe does,
and how the result is used. Docker runs the probe inside the container and
reports `healthy`, `unhealthy` or `starting` in `docker compose ps` and
`docker ps`; the probes are defined here, in the fragments, not in the service
images. What a probe exercises inside the service is owned by the service repo
and linked.

## Probes defined in the fragments

| Service | Profile | Probe (as written) | Interval | Timeout | Retries | Start period | Source |
|---|---|---|---|---|---|---|---|
| `mongo` | base | `mongo --quiet --eval <script>`: exits 0 only when `rs.status()` reports this node as PRIMARY. On error code 94 (`NotYetInitialized`) it runs `rs.initiate` for the single-node set `rs0`; on code 93 (`InvalidReplicaSetConfig`) it rewrites the member host to the current hostname with `replSetReconfig`. Either way it exits 1 on that run. | 15s | 10s | 5 | 90s | `compose/docker-compose.base.yml:101-129` |
| `pf_mosquitto` | base | `mosquitto_pub -t healthcheck/ping -m ok -u admin -P pfadminpw`: publishes the message `ok` to the topic `healthcheck/ping` on the container's own port 1883 as the `admin` user. | 10s | 5s | 3 | none | `compose/docker-compose.base.yml:173-189` |
| `auditgui` | base | `wget -qO- http://localhost:80/health-check \|\| exit 1`: HTTP GET of `/health-check` on the container's own port 80. | 10s | 5s | 3 | none | `compose/docker-compose.base.yml:250-254` |
| `ape_timescaledb` | ape | `pg_isready -U postgres` | 5s | 5s | 5 | none | `compose/docker-compose.ape.yml:92-96` |
| `perf_eval_mongo` | audit-perf-eval | Same script as `mongo` above. | 15s | 10s | 5 | 90s | `compose/docker-compose.audit-perf-eval.yml:95-120` |
| `record_video`, `stitch_videos` | tools | Disabled (`healthcheck: disable: true`): these are on-demand CLI containers. | | | | | `compose/docker-compose.tools.yml:25-26,44-45` |

Notes on individual probes:

- The `mongo` probe has side effects by design: it is the mechanism that
  initialises the replica set on first boot and re-binds it after a hostname
  change (comment at `compose/docker-compose.base.yml:101-105`). See the
  [MongoDB reference](mongodb.md).
- The `pf_mosquitto` probe is a loopback MQTT flow from the container to
  itself. It is not a row in the flow tables (it never leaves the container)
  but it is a real publish: every subscriber of `#` receives `ok` on
  `healthcheck/ping` every 10 seconds, and the probe carries the `admin`
  password in clear text in the fragment. The password originates in the
  pf_mosquitto image; rotating it means changing this line too
  ([MQTT clients](../architecture/integrations/mqtt-clients.md),
  pf_mosquitto [health check section](https://github.com/pacefactory/pf_mosquitto/blob/master/docs/architecture/README.md#health-check)).
- The `auditgui` probe depends on a `/health-check` route in the web GUI.
  TODO(source): link to the scv3_webgui reference for that endpoint once its
  docs are published.

## How the result is used

- **Start ordering.** Only one dependency waits for health:
  `expresso_server` depends on `ape_timescaledb` with
  `condition: service_healthy` (`compose/docker-compose.ape.yml:107-110`).
  Every other `depends_on` in the fragments is either the short list form or
  `condition: service_started` (`compose/docker-compose.expresso-010.yml:99-105,144-147,208-211,231`,
  `compose/docker-compose.expresso-030-trainer.yml:35-38`), which orders
  container start and does not consult the probe.
- **Operator visibility.** `docker compose ps` shows `(healthy)` or
  `(unhealthy)` next to the status of every service with a probe; the
  [update how-to](../how-to/update-a-deployment.md#verify) uses that as its
  completion check.
- **Restarts.** No fragment configures an action on `unhealthy`; `restart:
  always` restarts a container only when its main process exits.

## Services without a probe

`apigateway`, `dbserver`, `data_interconnector`, `realtime`,
`service_audit_processing`, `service_dtreeserver`, `service_gifwrapper`
(base); `expresso_server`, `expresso_ui`, `celery_worker`, `celery_beat`,
`redis`, `mongo_exp` (expresso-010); `trainer` (expresso-030-trainer);
`alert_processing_engine`, `ape_frame_playback` (ape); `perf_eval_dbserver`,
`service_audit_processing_perf_eval` (audit-perf-eval); `autozone`,
`autozone_api`, `autozone_mongo` (autozone); `certbot` (https-*); `nodered`
(node-red); `ntfy` (ntfy); `relational_dbserver` (rdb); `social_web_app`,
`social_video_server` (social); `swift-labeler` (swift-labeler).

TODO(source): the intent is for every service to expose a health check and
for every fragment to attach a probe to it; no fragment or issue in this
repository records that plan yet. Add the row here, and the endpoint or
command to the service repo's reference docs, as each service gains one.
