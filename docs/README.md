---
title: "Documentation index"
type: other
derived_from:
  - scripts/docs/index.tsv
  - docs/
last_verified: 2026-09-09
verified_against: 3630e2f
---

# Documentation index

Every file under `docs/` is listed here (standard §2). Generated files say so
in their first paragraph; edit their generator or data file under
`scripts/docs/` and run `scripts/docs/regenerate.sh` instead of editing them.
Read the two standards first:

- [Documentation standard (service repos)](DOCUMENTATION_STANDARD.md)
- [Architecture documentation standard (this repo)](architecture/ARCHITECTURE_DOCS_STANDARD.md)

## Architecture

| Doc | Purpose |
|---|---|
| [architecture/ARCHITECTURE_DOCS_STANDARD.md](architecture/ARCHITECTURE_DOCS_STANDARD.md) | Standard for the cross-repo architecture docs in this folder; extends the service-repo standard |
| [architecture/README.md](architecture/README.md) | Index of every diagram in this repo: what it shows, derived from, last verified |
| [architecture/glossary.md](architecture/glossary.md) | Authoritative vocabulary, service node IDs, owning repos and external integration IDs (generated) |
| [architecture/system-context.mmd](architecture/system-context.mmd) | Pacefactory deployment as one box with every external actor and system |
| [architecture/integrations/README.md](architecture/integrations/README.md) | Catalogue of external integration types |
| [architecture/integrations/cameras-rtsp.md](architecture/integrations/cameras-rtsp.md) | IP cameras streaming RTSP into realtime and record_video |
| [architecture/integrations/mqtt-clients.md](architecture/integrations/mqtt-clients.md) | Third-party MQTT clients of the deployment's own broker |
| [architecture/integrations/client-sql.md](architecture/integrations/client-sql.md) | A client's SQL database behind relational_dbserver |
| [architecture/integrations/acme-dns.md](architecture/integrations/acme-dns.md) | Let's Encrypt and the DigitalOcean / GoDaddy DNS APIs used by certbot |
| [architecture/integrations/peer-deployments.md](architecture/integrations/peer-deployments.md) | Remote-training exchange between Pacefactory deployments |
| [architecture/integrations/registry-egress.md](architecture/integrations/registry-egress.md) | Docker Hub and GitHub egress from the host tooling |
| [architecture/integrations/web-clients.md](architecture/integrations/web-clients.md) | Published HTTP(S) ports and the clients that use them |
| [architecture/integrations/host-filesystem.md](architecture/integrations/host-filesystem.md) | Host paths bind-mounted into containers |
| [architecture/integrations/push-clients.md](architecture/integrations/push-clients.md) | ntfy push notification subscribers |
| [architecture/integrations/node-red-flows.md](architecture/integrations/node-red-flows.md) | Endpoints reached by a site's Node-RED flows |
| [architecture/integrations/corporate-proxy.md](architecture/integrations/corporate-proxy.md) | Egress proxy hook on the deployment host |
| [architecture/integrations/fleet-ssh.md](architecture/integrations/fleet-ssh.md) | Fleet operator workstation updating hosts over SSH |
| [architecture/network/site-requirements.md](architecture/network/site-requirements.md) | Client site network requirements evidenced by this repo (carve-out, to be completed) |
| [architecture/network/site-network.mmd](architecture/network/site-network.mmd) | On-premises network diagram of the evidenced elements |

### Profiles (generated)

| Profile page | Diagram | Purpose |
|---|---|---|
| [architecture/profiles/ape.md](architecture/profiles/ape.md) | [ape.mmd](architecture/profiles/ape.mmd) | APE profile profile: services, settings and flows contributed by `ape` |
| [architecture/profiles/audit-perf-eval.md](architecture/profiles/audit-perf-eval.md) | [audit-perf-eval.mmd](architecture/profiles/audit-perf-eval.mmd) | audit perf-eval shadow profile profile: services, settings and flows contributed by `audit-perf-eval` |
| [architecture/profiles/autozone.md](architecture/profiles/autozone.md) | [autozone.mmd](architecture/profiles/autozone.mmd) | Autozone profile profile: services, settings and flows contributed by `autozone` |
| [architecture/profiles/base.md](architecture/profiles/base.md) | [base.mmd](architecture/profiles/base.mmd) |  profile: services, settings and flows contributed by `base` |
| [architecture/profiles/cuda.md](architecture/profiles/cuda.md) | [cuda.mmd](architecture/profiles/cuda.mmd) | Realtime CUDA profile: services, settings and flows contributed by `cuda` |
| [architecture/profiles/expresso-010.md](architecture/profiles/expresso-010.md) | [expresso-010.mmd](architecture/profiles/expresso-010.mmd) | Expresso profile profile: services, settings and flows contributed by `expresso-010` |
| [architecture/profiles/expresso-020-cuda.md](architecture/profiles/expresso-020-cuda.md) | [expresso-020-cuda.mmd](architecture/profiles/expresso-020-cuda.mmd) | Expresso CUDA profile: services, settings and flows contributed by `expresso-020-cuda` |
| [architecture/profiles/expresso-030-trainer.md](architecture/profiles/expresso-030-trainer.md) | [expresso-030-trainer.mmd](architecture/profiles/expresso-030-trainer.mmd) | Expresso Trainer profile: services, settings and flows contributed by `expresso-030-trainer` |
| [architecture/profiles/https-digitalocean.md](architecture/profiles/https-digitalocean.md) | [https-digitalocean.mmd](architecture/profiles/https-digitalocean.mmd) | HTTPS (Digital Ocean) profile: services, settings and flows contributed by `https-digitalocean` |
| [architecture/profiles/https-godaddy.md](architecture/profiles/https-godaddy.md) | [https-godaddy.mmd](architecture/profiles/https-godaddy.mmd) | HTTPS (GoDaddy) profile: services, settings and flows contributed by `https-godaddy` |
| [architecture/profiles/https-manual.md](architecture/profiles/https-manual.md) | [https-manual.mmd](architecture/profiles/https-manual.mmd) | HTTPS (Manual) profile: services, settings and flows contributed by `https-manual` |
| [architecture/profiles/https-no-certbot.md](architecture/profiles/https-no-certbot.md) | [https-no-certbot.mmd](architecture/profiles/https-no-certbot.mmd) | HTTPS (manual, no certbot) profile: services, settings and flows contributed by `https-no-certbot` |
| [architecture/profiles/mqtt-public.md](architecture/profiles/mqtt-public.md) | [mqtt-public.mmd](architecture/profiles/mqtt-public.mmd) | Public MQTT (port 1883) profile: services, settings and flows contributed by `mqtt-public` |
| [architecture/profiles/mqtts-public.md](architecture/profiles/mqtts-public.md) | [mqtts-public.mmd](architecture/profiles/mqtts-public.mmd) | Public MQTTS (port 8883) profile: services, settings and flows contributed by `mqtts-public` |
| [architecture/profiles/node-red.md](architecture/profiles/node-red.md) | [node-red.mmd](architecture/profiles/node-red.mmd) | node-red profile profile: services, settings and flows contributed by `node-red` |
| [architecture/profiles/ntfy.md](architecture/profiles/ntfy.md) | [ntfy.mmd](architecture/profiles/ntfy.mmd) | ntfy profile profile: services, settings and flows contributed by `ntfy` |
| [architecture/profiles/offline.md](architecture/profiles/offline.md) | [offline.mmd](architecture/profiles/offline.mmd) | OFFLINE MODE profile: services, settings and flows contributed by `offline` |
| [architecture/profiles/rdb.md](architecture/profiles/rdb.md) | [rdb.mmd](architecture/profiles/rdb.mmd) | relational dbserver profile profile: services, settings and flows contributed by `rdb` |
| [architecture/profiles/service-ports.md](architecture/profiles/service-ports.md) | [service-ports.mmd](architecture/profiles/service-ports.mmd) | Service Ports profile: services, settings and flows contributed by `service-ports` |
| [architecture/profiles/social.md](architecture/profiles/social.md) | [social.mmd](architecture/profiles/social.mmd) | social profile profile: services, settings and flows contributed by `social` |
| [architecture/profiles/swift-labeler.md](architecture/profiles/swift-labeler.md) | [swift-labeler.mmd](architecture/profiles/swift-labeler.mmd) | Swift Labeler profile: services, settings and flows contributed by `swift-labeler` |
| [architecture/profiles/tools.md](architecture/profiles/tools.md) | [tools.mmd](architecture/profiles/tools.mmd) | Tools profile profile: services, settings and flows contributed by `tools` |

### Reference deployments (generated)

| Deployment | Files |
|---|---|
| [Default build](architecture/reference-deployments/default-build/README.md) | [.env](architecture/reference-deployments/default-build/.env), [.settings](architecture/reference-deployments/default-build/.settings), [build-command.txt](architecture/reference-deployments/default-build/build-command.txt), [docker-compose.built.yml](architecture/reference-deployments/default-build/docker-compose.built.yml), [topology.mmd](architecture/reference-deployments/default-build/topology.mmd), [data-flows.mmd](architecture/reference-deployments/default-build/data-flows.mmd), [request-flows.mmd](architecture/reference-deployments/default-build/request-flows.mmd) |
| [GPU variant](architecture/reference-deployments/gpu/README.md) | [.env](architecture/reference-deployments/gpu/.env), [.settings](architecture/reference-deployments/gpu/.settings), [build-command.txt](architecture/reference-deployments/gpu/build-command.txt), [docker-compose.built.yml](architecture/reference-deployments/gpu/docker-compose.built.yml), [topology.mmd](architecture/reference-deployments/gpu/topology.mmd), [data-flows.mmd](architecture/reference-deployments/gpu/data-flows.mmd), [request-flows.mmd](architecture/reference-deployments/gpu/request-flows.mmd) |
| [HTTPS via DigitalOcean](architecture/reference-deployments/https-digitalocean/README.md) | [.env](architecture/reference-deployments/https-digitalocean/.env), [.settings](architecture/reference-deployments/https-digitalocean/.settings), [build-command.txt](architecture/reference-deployments/https-digitalocean/build-command.txt), [docker-compose.built.yml](architecture/reference-deployments/https-digitalocean/docker-compose.built.yml), [topology.mmd](architecture/reference-deployments/https-digitalocean/topology.mmd), [data-flows.mmd](architecture/reference-deployments/https-digitalocean/data-flows.mmd), [request-flows.mmd](architecture/reference-deployments/https-digitalocean/request-flows.mmd) |
| [HTTPS via TLS cert file](architecture/reference-deployments/https-cert-file/README.md) | [.env](architecture/reference-deployments/https-cert-file/.env), [.settings](architecture/reference-deployments/https-cert-file/.settings), [build-command.txt](architecture/reference-deployments/https-cert-file/build-command.txt), [docker-compose.built.yml](architecture/reference-deployments/https-cert-file/docker-compose.built.yml), [topology.mmd](architecture/reference-deployments/https-cert-file/topology.mmd), [data-flows.mmd](architecture/reference-deployments/https-cert-file/data-flows.mmd), [request-flows.mmd](architecture/reference-deployments/https-cert-file/request-flows.mmd) |
| [Full alerting](architecture/reference-deployments/alerting/README.md) | [.env](architecture/reference-deployments/alerting/.env), [.settings](architecture/reference-deployments/alerting/.settings), [build-command.txt](architecture/reference-deployments/alerting/build-command.txt), [docker-compose.built.yml](architecture/reference-deployments/alerting/docker-compose.built.yml), [topology.mmd](architecture/reference-deployments/alerting/topology.mmd), [data-flows.mmd](architecture/reference-deployments/alerting/data-flows.mmd), [request-flows.mmd](architecture/reference-deployments/alerting/request-flows.mmd) |
| [Offline processing](architecture/reference-deployments/offline-processing/README.md) | [.env](architecture/reference-deployments/offline-processing/.env), [.settings](architecture/reference-deployments/offline-processing/.settings), [build-command.txt](architecture/reference-deployments/offline-processing/build-command.txt), [docker-compose.built.yml](architecture/reference-deployments/offline-processing/docker-compose.built.yml), [topology.mmd](architecture/reference-deployments/offline-processing/topology.mmd), [data-flows.mmd](architecture/reference-deployments/offline-processing/data-flows.mmd), [request-flows.mmd](architecture/reference-deployments/offline-processing/request-flows.mmd) |

## Reference

| Doc | Purpose |
|---|---|
| [reference/build-script.md](reference/build-script.md) | Flags, inputs, outputs and pitfalls of build.sh and update.sh |
| [reference/environment-variables.md](reference/environment-variables.md) | Every variable build.sh reads or a fragment interpolates, with defaults and destinations (generated) |
| [reference/profile-dependencies.md](reference/profile-dependencies.md) | Sub-profile, requires and inferred-conflict graph of the build profiles (generated) |
| [reference/profile-metadata.md](reference/profile-metadata.md) | The x-pf-info schema build.sh reads from fragments |
| [reference/mqtt-broker-listeners.md](reference/mqtt-broker-listeners.md) | Which pf_mosquitto listeners each profile publishes |
| [reference/ghosting.md](reference/ghosting.md) | Ghosting enforcement variables and modes |
| [reference/mongodb.md](reference/mongodb.md) | How the main mongo service is sized and run as a single-node replica set |
| [reference/backup-restore-cli.md](reference/backup-restore-cli.md) | Options of the volume backup and restore scripts and the volumes they cover |

## How-to

| Doc | Purpose |
|---|---|
| [how-to/build-a-deployment.md](how-to/build-a-deployment.md) | Choose profiles and settings and produce docker-compose.yml |
| [how-to/update-a-deployment.md](how-to/update-a-deployment.md) | Pull images and relaunch the compose project |
| [how-to/add-a-profile.md](how-to/add-a-profile.md) | Add a compose fragment and its derived docs |
| [how-to/add-an-environment-variable.md](how-to/add-an-environment-variable.md) | Expose a new build-time variable to a service |
| [how-to/rebuild-reference-deployments.md](how-to/rebuild-reference-deployments.md) | Rebuild the committed reference outputs and regenerate all derived docs |
| [how-to/record-and-stitch-video.md](how-to/record-and-stitch-video.md) | Record an RTSP camera to disk and stitch the segments |
| [how-to/import-ssl-certificate.md](how-to/import-ssl-certificate.md) | Convert a .pfx bundle into the cert files the https-no-certbot profile serves |
| [how-to/enable-https.md](how-to/enable-https.md) | Enable one of the https-* profiles and obtain a certificate |
| [how-to/back-up-volumes.md](how-to/back-up-volumes.md) | Archive the data volumes locally or to another server |
| [how-to/restore-volumes.md](how-to/restore-volumes.md) | Load volume archives into a deployment |
| [how-to/migrate-to-a-new-server.md](how-to/migrate-to-a-new-server.md) | Move a deployment's volumes to a new host |
| [how-to/update-fleet-from-windows.md](how-to/update-fleet-from-windows.md) | Update many servers over ssh from a Windows workstation |
| [how-to/install-yq.md](how-to/install-yq.md) | Install mikefarah yq v4 for build.sh |
| [how-to/install-cuda-support.md](how-to/install-cuda-support.md) | Prepare a host for the GPU sub-profiles (placeholder) |
| [how-to/verify-mongodb.md](how-to/verify-mongodb.md) | Check replica set state, cache size and OOM history of mongo |
| [how-to/tune-mongodb-performance.md](how-to/tune-mongodb-performance.md) | Diagnose slow writes and adjust one knob at a time |
| [how-to/roll-back-mongodb-replica-set.md](how-to/roll-back-mongodb-replica-set.md) | Return mongo to a standalone mongod |
| [how-to/create-an-offline-install.md](how-to/create-an-offline-install.md) | Package Docker, images and an installer for a host without internet |
| [how-to/sync-documentation-standard.md](how-to/sync-documentation-standard.md) | Refresh or verify the vendored copy of the documentation standard in service repos |

## Design notes and other

| Doc | Purpose |
|---|---|
| [design/mongodb-memory-bounding.md](design/mongodb-memory-bounding.md) | Why mongo runs memory-bounded as a single-node replica set |
| [upgrade-notes.md](upgrade-notes.md) | Behaviour changes operators need to know about per release |
| [DOCUMENTATION_STANDARD.md](DOCUMENTATION_STANDARD.md) | Canonical documentation standard for every Pacefactory service repository |

## Colocated READMEs outside docs/

| File | Purpose |
|---|---|
| [scripts/remote/README.md](../scripts/remote/README.md) | Pointer to the fleet update how-to (colocated with the scripts) |
| [scv2_base_images/README.md](../scv2_base_images/README.md) | How the shared base images are built and pushed (colocated with their Dockerfiles) |

## Tooling (not docs)

Generators and data files live in `scripts/docs/`: `regenerate.sh`, `build-reference-deployment.sh`, `render-*.sh`, `check-docs.sh`, and the data files `services.tsv`, `externals.tsv`, `flows.tsv`, `deployments.tsv`, `index.tsv`, `request-flows/*.mmd`.
