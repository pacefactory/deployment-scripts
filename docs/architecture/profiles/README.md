---
title: "Profile catalog"
type: reference
derived_from:
  - compose/docker-compose.*.yml
  - build.sh
  - scripts/docs/flows.tsv
  - scripts/docs/services.tsv
last_verified: 2026-09-10
verified_against: ba84b53
---

# Profile catalog

Every build profile `build.sh` knows about, derived from the fragments in
`compose/` and the classification constants in `build.sh`. A fragment missing
from this table is a docs defect; regenerate with
`scripts/docs/render-profile-catalog.sh`. Vocabulary: [glossary](../glossary.md).

`custom` is force-enabled by `build.sh` but has no fragment in the repository
(`compose/docker-compose.custom.yml` is gitignored). A site may add one; it is
merged in alphabetical position, after `base` and before `expresso-010`, so it
cannot override anything a later fragment sets.

| Profile | Class | Services added | Networks / volumes added | External integrations enabled | Parent | Requires | Required by | Conflicts with (inferred) | Owning service repo(s) | Page |
|---|---|---|---|---|---|---|---|---|---|---|
| `ape` | prompted, default off | `alert_processing_engine`, `ape_frame_playback`, `ape_timescaledb` (modifies `apigateway`, `expresso_server`, `data_interconnector`) | volumes: ape-data, ape_timescaledb-data | `ext_web_clients` | none | [`expresso-010`](expresso-010.md), [`rdb`](rdb.md) | none | none found | [alert_processing_engine](https://github.com/pacefactory/alert_processing_engine)<br>[alert_processing_engine](https://github.com/pacefactory/alert_processing_engine) | [ape.md](ape.md) |
| `audit-perf-eval` | prompted, default off | `perf_eval_mongo`, `perf_eval_dbserver`, `service_audit_processing_perf_eval` | volumes: perf_eval-mongodata, perf_eval-dbserver-data, perf_eval-audit_processing-data | `ext_web_clients` | none | none | none | none found | [scv2_dbserver](https://github.com/pacefactory/scv2_dbserver)<br>[scv3_services_processing](https://github.com/pacefactory/scv3_services_processing) | [audit-perf-eval.md](audit-perf-eval.md) |
| `autozone` | prompted, default off | `autozone`, `autozone_api`, `autozone_mongo` (modifies `apigateway`, `service_audit_processing`) | networks: autozone_network; volumes: autozone_mongo-data, autozone-data | none | none | none | none | none found | [autozone](https://github.com/pacefactory/autozone)<br>[autozone](https://github.com/pacefactory/autozone) | [autozone.md](autozone.md) |
| `base` | forced (build.sh) | `mongo`, `dbserver`, `pf_mosquitto`, `data_interconnector`, `realtime`, `auditgui`, `service_gifwrapper`, `service_dtreeserver`, `service_audit_processing`, `apigateway` | networks: internal_network, external_network; volumes: mongodata, dbserver-data, realtime-data, service_dtreeserver-data, webgui-data, mosquitto-data, data_interconnector-data, audit_processing-data | `ext_cameras`, `ext_web_clients` | none | none | none | none found | [scv2_dbserver](https://github.com/pacefactory/scv2_dbserver)<br>[pf_mosquitto](https://github.com/pacefactory/pf_mosquitto)<br>[data_interconnector](https://github.com/pacefactory/data_interconnector)<br>[scv2_realtime](https://github.com/pacefactory/scv2_realtime)<br>[scv3_webgui](https://github.com/pacefactory/scv3_webgui)<br>[scv2_services_gifwrapper](https://github.com/pacefactory/scv2_services_gifwrapper)<br>[scv2_services_dtreeserver](https://github.com/pacefactory/scv2_services_dtreeserver)<br>[scv3_services_processing](https://github.com/pacefactory/scv3_services_processing)<br>[scv2_apigateway](https://github.com/pacefactory/scv2_apigateway) | [base.md](base.md) |
| `cuda` | sub-profile of base, default off | none (modifies `realtime`) | none | none | [`base`](base.md) | none | none | none found | third-party images only | [cuda.md](cuda.md) |
| `expresso-010` | forced (build.sh) | `expresso_server`, `expresso_ui`, `redis`, `celery_worker`, `celery_beat`, `mongo_exp` (modifies `auditgui`, `apigateway`) | networks: expresso_network; volumes: expresso-data, mongodata_exp | `ext_peer_deployment` | none | none | [`ape`](ape.md) | none found | [expresso_server](https://github.com/pacefactory/expresso_server)<br>[expresso_ui](https://github.com/pacefactory/expresso_ui)<br>[expresso_server](https://github.com/pacefactory/expresso_server)<br>[expresso_server](https://github.com/pacefactory/expresso_server) | [expresso-010.md](expresso-010.md) |
| `expresso-020-cuda` | sub-profile of expresso-010, default off | none (modifies `celery_worker`) | none | none | [`expresso-010`](expresso-010.md) | none | none | none found | third-party images only | [expresso-020-cuda.md](expresso-020-cuda.md) |
| `expresso-030-trainer` | sub-profile of expresso-010, default off | `trainer` | none | none | [`expresso-010`](expresso-010.md) | none | none | none found | [trainer](https://github.com/pacefactory/trainer) | [expresso-030-trainer.md](expresso-030-trainer.md) |
| `https-digitalocean` | prompted, default off | `certbot` (modifies `apigateway`) | volumes: certbot | `ext_acme`, `ext_dns_api`, `ext_web_clients` | none | none | none | `https-godaddy` (same container name certbot; same host port 443)<br>`https-manual` (same container name certbot; same host port 443)<br>`https-no-certbot` (same host port 443) | third-party images only | [https-digitalocean.md](https-digitalocean.md) |
| `https-godaddy` | prompted, default off | `certbot` (modifies `apigateway`) | volumes: certbot | `ext_acme`, `ext_dns_api`, `ext_web_clients` | none | none | none | `https-digitalocean` (same container name certbot; same host port 443)<br>`https-manual` (same container name certbot; same host port 443)<br>`https-no-certbot` (same host port 443) | third-party images only | [https-godaddy.md](https-godaddy.md) |
| `https-manual` | prompted, default off | `certbot` (modifies `apigateway`) | volumes: certbot | `ext_acme`, `ext_web_clients` | none | none | none | `https-digitalocean` (same container name certbot; same host port 443)<br>`https-godaddy` (same container name certbot; same host port 443)<br>`https-no-certbot` (same host port 443) | third-party images only | [https-manual.md](https-manual.md) |
| `https-no-certbot` | prompted, default off | none (modifies `apigateway`) | none | `ext_host_fs`, `ext_web_clients` | none | none | none | `https-digitalocean` (same host port 443)<br>`https-godaddy` (same host port 443)<br>`https-manual` (same host port 443) | third-party images only | [https-no-certbot.md](https-no-certbot.md) |
| `mqtt-public` | sub-profile of base, default on | none (modifies `pf_mosquitto`) | none | `ext_mqtt_clients` | [`base`](base.md) | none | none | none found | third-party images only | [mqtt-public.md](mqtt-public.md) |
| `mqtts-public` | sub-profile of https-digitalocean, https-godaddy, https-manual, https-no-certbot, default on | none (modifies `pf_mosquitto`) | none | `ext_mqtt_clients` | [`https-digitalocean`](https-digitalocean.md), [`https-godaddy`](https-godaddy.md), [`https-manual`](https-manual.md), [`https-no-certbot`](https-no-certbot.md) | none | none | none found | third-party images only | [mqtts-public.md](mqtts-public.md) |
| `node-red` | prompted, default on | `nodered` (modifies `apigateway`) | volumes: nodered-data | `ext_nodered_endpoints`, `ext_web_clients` | none | none | none | none found | third-party images only | [node-red.md](node-red.md) |
| `ntfy` | prompted, default off | `ntfy` | volumes: ntfy-cache, ntfy-data | `ext_ntfy_clients` | none | none | none | none found | third-party images only | [ntfy.md](ntfy.md) |
| `offline` | prompted, default off | none (modifies `dbserver`, `service_audit_processing`) | none | none | none | none | none | none found | third-party images only | [offline.md](offline.md) |
| `rdb` | prompted, default on | `relational_dbserver` (modifies `apigateway`, `auditgui`, `service_audit_processing`, `expresso_server`) | volumes: relational_dbserver-data | `ext_client_sql`, `ext_web_clients` | none | none | [`ape`](ape.md) | none found | [scv2_relational_dbserver](https://github.com/pacefactory/scv2_relational_dbserver) | [rdb.md](rdb.md) |
| `service-ports` | prompted, default off | none (modifies `service_gifwrapper`, `service_dtreeserver`) | none | `ext_web_clients` | none | none | none | none found | third-party images only | [service-ports.md](service-ports.md) |
| `social` | prompted, default on | `social_web_app`, `social_video_server` (modifies `apigateway`) | volumes: social_video_server-data | `ext_web_clients` | none | none | none | none found | [social_web_app](https://github.com/pacefactory/social_web_app)<br>[social_video_server](https://github.com/pacefactory/social_video_server) | [social.md](social.md) |
| `swift-labeler` | prompted, default off | `swift-labeler` (modifies `apigateway`, `service_audit_processing`) | volumes: swift-labeler-data, swift-labeler-static | `ext_web_clients` | none | none | none | none found | [swift-labeler](https://github.com/pacefactory/swift-labeler) | [swift-labeler.md](swift-labeler.md) |
| `tools` | forced (build.sh) | `record_video`, `stitch_videos` | none | `ext_cameras`, `ext_host_fs` | none | none | none | none found | [deployment-scripts](https://github.com/pacefactory/deployment-scripts)<br>[deployment-scripts](https://github.com/pacefactory/deployment-scripts) | [tools.md](tools.md) |
| `custom` | forced (build.sh); fragment absent | site-defined | site-defined | site-defined | none | none | none | unknown | site | none |
