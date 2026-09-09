---
title: "Architecture documentation"
type: other
derived_from:
  - docs/architecture/**/*.mmd
  - docs/reference/profile-dependencies.md
last_verified: 2026-09-09
verified_against: 3630e2f
---

# Architecture documentation

How Pacefactory services are composed into a deployment. Governed by the
[architecture documentation standard](ARCHITECTURE_DOCS_STANDARD.md). Start with
the [glossary](glossary.md), then the [profile catalog](profiles/README.md), then
the [reference deployments](reference-deployments/README.md).

- [System context](system-context.mmd) and [integrations](integrations/README.md): what is outside the deployment.
- [Profiles](profiles/README.md): what each fragment adds.
- [Reference deployments](reference-deployments/README.md): six built variants with topology, data-flow and request-flow diagrams.
- [Network](network/site-requirements.md): what a client site must provide (carve-out).

## Diagrams

Every Mermaid source in this repository. All are validated with mermaid-cli by
`scripts/docs/check-docs.sh --mermaid`.

| Diagram file | What it shows | Derived from | Last verified |
|---|---|---|---|
| [network/site-network.mmd](network/site-network.mmd) | Client site network elements evidenced by this repo | `docs/architecture/network/site-requirements.md`, `scripts/remote/update-server.sh`, `compose/docker-compose.*.yml` | 2026-09-09 (def9139) |
| [profiles/ape.mmd](profiles/ape.mmd) | Services and flows contributed by profile `ape` | `compose/docker-compose.ape.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/audit-perf-eval.mmd](profiles/audit-perf-eval.mmd) | Services and flows contributed by profile `audit-perf-eval` | `compose/docker-compose.audit-perf-eval.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/autozone.mmd](profiles/autozone.mmd) | Services and flows contributed by profile `autozone` | `compose/docker-compose.autozone.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/base.mmd](profiles/base.mmd) | Services and flows contributed by profile `base` | `compose/docker-compose.base.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/cuda.mmd](profiles/cuda.mmd) | Services and flows contributed by profile `cuda` | `compose/docker-compose.cuda.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/expresso-010.mmd](profiles/expresso-010.mmd) | Services and flows contributed by profile `expresso-010` | `compose/docker-compose.expresso-010.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/expresso-020-cuda.mmd](profiles/expresso-020-cuda.mmd) | Services and flows contributed by profile `expresso-020-cuda` | `compose/docker-compose.expresso-020-cuda.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/expresso-030-trainer.mmd](profiles/expresso-030-trainer.mmd) | Services and flows contributed by profile `expresso-030-trainer` | `compose/docker-compose.expresso-030-trainer.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/https-digitalocean.mmd](profiles/https-digitalocean.mmd) | Services and flows contributed by profile `https-digitalocean` | `compose/docker-compose.https-digitalocean.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/https-godaddy.mmd](profiles/https-godaddy.mmd) | Services and flows contributed by profile `https-godaddy` | `compose/docker-compose.https-godaddy.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/https-manual.mmd](profiles/https-manual.mmd) | Services and flows contributed by profile `https-manual` | `compose/docker-compose.https-manual.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/https-no-certbot.mmd](profiles/https-no-certbot.mmd) | Services and flows contributed by profile `https-no-certbot` | `compose/docker-compose.https-no-certbot.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/mqtt-public.mmd](profiles/mqtt-public.mmd) | Services and flows contributed by profile `mqtt-public` | `compose/docker-compose.mqtt-public.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/mqtts-public.mmd](profiles/mqtts-public.mmd) | Services and flows contributed by profile `mqtts-public` | `compose/docker-compose.mqtts-public.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/node-red.mmd](profiles/node-red.mmd) | Services and flows contributed by profile `node-red` | `compose/docker-compose.node-red.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/ntfy.mmd](profiles/ntfy.mmd) | Services and flows contributed by profile `ntfy` | `compose/docker-compose.ntfy.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/offline.mmd](profiles/offline.mmd) | Services and flows contributed by profile `offline` | `compose/docker-compose.offline.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/rdb.mmd](profiles/rdb.mmd) | Services and flows contributed by profile `rdb` | `compose/docker-compose.rdb.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/service-ports.mmd](profiles/service-ports.mmd) | Services and flows contributed by profile `service-ports` | `compose/docker-compose.service-ports.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/social.mmd](profiles/social.mmd) | Services and flows contributed by profile `social` | `compose/docker-compose.social.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/swift-labeler.mmd](profiles/swift-labeler.mmd) | Services and flows contributed by profile `swift-labeler` | `compose/docker-compose.swift-labeler.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [profiles/tools.mmd](profiles/tools.mmd) | Services and flows contributed by profile `tools` | `compose/docker-compose.tools.yml`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/alerting/data-flows.mmd](reference-deployments/alerting/data-flows.mmd) | Data flows of reference deployment `alerting` | `docs/architecture/reference-deployments/alerting/docker-compose.built.yml`, `docs/architecture/reference-deployments/alerting/.settings`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/alerting/request-flows.mmd](reference-deployments/alerting/request-flows.mmd) | Primary request sequences of reference deployment `alerting` | `docs/architecture/reference-deployments/alerting/docker-compose.built.yml`, `scripts/docs/request-flows/alerting.mmd` | 2026-09-09 (def9139) |
| [reference-deployments/alerting/topology.mmd](reference-deployments/alerting/topology.mmd) | Topology of reference deployment `alerting`: services, networks, volumes, published ports | `docs/architecture/reference-deployments/alerting/docker-compose.built.yml`, `scripts/docs/services.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/default-build/data-flows.mmd](reference-deployments/default-build/data-flows.mmd) | Data flows of reference deployment `default-build` | `docs/architecture/reference-deployments/default-build/docker-compose.built.yml`, `docs/architecture/reference-deployments/default-build/.settings`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/default-build/request-flows.mmd](reference-deployments/default-build/request-flows.mmd) | Primary request sequences of reference deployment `default-build` | `docs/architecture/reference-deployments/default-build/docker-compose.built.yml`, `scripts/docs/request-flows/default.mmd` | 2026-09-09 (def9139) |
| [reference-deployments/default-build/topology.mmd](reference-deployments/default-build/topology.mmd) | Topology of reference deployment `default-build`: services, networks, volumes, published ports | `docs/architecture/reference-deployments/default-build/docker-compose.built.yml`, `scripts/docs/services.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/gpu/data-flows.mmd](reference-deployments/gpu/data-flows.mmd) | Data flows of reference deployment `gpu` | `docs/architecture/reference-deployments/gpu/docker-compose.built.yml`, `docs/architecture/reference-deployments/gpu/.settings`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/gpu/request-flows.mmd](reference-deployments/gpu/request-flows.mmd) | Primary request sequences of reference deployment `gpu` | `docs/architecture/reference-deployments/gpu/docker-compose.built.yml`, `scripts/docs/request-flows/default.mmd` | 2026-09-09 (def9139) |
| [reference-deployments/gpu/topology.mmd](reference-deployments/gpu/topology.mmd) | Topology of reference deployment `gpu`: services, networks, volumes, published ports | `docs/architecture/reference-deployments/gpu/docker-compose.built.yml`, `scripts/docs/services.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/https-cert-file/data-flows.mmd](reference-deployments/https-cert-file/data-flows.mmd) | Data flows of reference deployment `https-cert-file` | `docs/architecture/reference-deployments/https-cert-file/docker-compose.built.yml`, `docs/architecture/reference-deployments/https-cert-file/.settings`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/https-cert-file/request-flows.mmd](reference-deployments/https-cert-file/request-flows.mmd) | Primary request sequences of reference deployment `https-cert-file` | `docs/architecture/reference-deployments/https-cert-file/docker-compose.built.yml`, `scripts/docs/request-flows/tls-file.mmd` | 2026-09-09 (def9139) |
| [reference-deployments/https-cert-file/topology.mmd](reference-deployments/https-cert-file/topology.mmd) | Topology of reference deployment `https-cert-file`: services, networks, volumes, published ports | `docs/architecture/reference-deployments/https-cert-file/docker-compose.built.yml`, `scripts/docs/services.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/https-digitalocean/data-flows.mmd](reference-deployments/https-digitalocean/data-flows.mmd) | Data flows of reference deployment `https-digitalocean` | `docs/architecture/reference-deployments/https-digitalocean/docker-compose.built.yml`, `docs/architecture/reference-deployments/https-digitalocean/.settings`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/https-digitalocean/request-flows.mmd](reference-deployments/https-digitalocean/request-flows.mmd) | Primary request sequences of reference deployment `https-digitalocean` | `docs/architecture/reference-deployments/https-digitalocean/docker-compose.built.yml`, `scripts/docs/request-flows/tls-certbot.mmd` | 2026-09-09 (def9139) |
| [reference-deployments/https-digitalocean/topology.mmd](reference-deployments/https-digitalocean/topology.mmd) | Topology of reference deployment `https-digitalocean`: services, networks, volumes, published ports | `docs/architecture/reference-deployments/https-digitalocean/docker-compose.built.yml`, `scripts/docs/services.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/offline-processing/data-flows.mmd](reference-deployments/offline-processing/data-flows.mmd) | Data flows of reference deployment `offline-processing` | `docs/architecture/reference-deployments/offline-processing/docker-compose.built.yml`, `docs/architecture/reference-deployments/offline-processing/.settings`, `scripts/docs/flows.tsv`, `scripts/docs/services.tsv`, `scripts/docs/externals.tsv` | 2026-09-09 (def9139) |
| [reference-deployments/offline-processing/request-flows.mmd](reference-deployments/offline-processing/request-flows.mmd) | Primary request sequences of reference deployment `offline-processing` | `docs/architecture/reference-deployments/offline-processing/docker-compose.built.yml`, `scripts/docs/request-flows/default.mmd` | 2026-09-09 (def9139) |
| [reference-deployments/offline-processing/topology.mmd](reference-deployments/offline-processing/topology.mmd) | Topology of reference deployment `offline-processing`: services, networks, volumes, published ports | `docs/architecture/reference-deployments/offline-processing/docker-compose.built.yml`, `scripts/docs/services.tsv` | 2026-09-09 (def9139) |
| [system-context.mmd](system-context.mmd) | Pacefactory deployment as one system with external actors and systems | `scripts/docs/externals.tsv`, `scripts/docs/flows.tsv`, `compose/docker-compose.*.yml`, `scripts/remote/update-server.sh`, `update.sh` | 2026-09-09 (ccf3768) |
| [../reference/profile-dependencies.md](../reference/profile-dependencies.md) (embedded) | Sub-profile, requires and inferred-conflict edges between build profiles | `compose/docker-compose.*.yml`, `build.sh` | see file header |
