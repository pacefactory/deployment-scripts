# deployment-scripts

Scripts and compose fragments that build and run a Pacefactory deployment: one
Docker Compose project assembled by `build.sh` from the profiles under
`compose/`, launched and updated by `update.sh`.

All documentation lives under [`docs/`](docs/README.md). This repository also
owns the Pacefactory documentation standards and the cross-repo architecture
documentation (profiles, reference deployments, data flows, integrations).

## Quick start

Prerequisites: a Linux host with Docker and the docker compose plugin (Docker
28.x with compose 2.35+ confirmed), mikefarah `yq` v4 on PATH
([Install yq](docs/how-to/install-yq.md); the Python `yq` wrapper is not
compatible), and the repository checked out at
`~/scv2/git_clones/deployment-scripts`.

```bash
./build.sh     # choose profiles and settings; writes .settings, .env, docker-compose.yml
./update.sh    # pull images and (re)launch; offers to run build.sh first
```

Non-interactive: `./build.sh -q` then `./update.sh -q`. Details:
[Build a deployment](docs/how-to/build-a-deployment.md),
[Update a deployment](docs/how-to/update-a-deployment.md),
[Build and update scripts reference](docs/reference/build-script.md).

## Where to look

| Need | Doc |
|---|---|
| What profiles exist and what each adds | [Profile catalog](docs/architecture/profiles/README.md) |
| Every build variable, its default and where it reaches | [Environment variable reference](docs/reference/environment-variables.md) |
| A built example of a real deployment class, with diagrams | [Reference deployments](docs/architecture/reference-deployments/README.md) |
| What talks to what, in and out of the deployment | [Integrations](docs/architecture/integrations/README.md), [glossary](docs/architecture/glossary.md) |
| HTTPS, MQTT listeners, ghosting, MongoDB sizing | [Enable HTTPS](docs/how-to/enable-https.md), [MQTT broker listeners](docs/reference/mqtt-broker-listeners.md), [Ghosting](docs/reference/ghosting.md), [MongoDB](docs/reference/mongodb.md) |
| Backups, migration, fleet updates, offline installs | [How-to index](docs/README.md#how-to) |
| Recording camera video | [Record and stitch video](docs/how-to/record-and-stitch-video.md) |
| What changed between releases | [Upgrade notes](docs/upgrade-notes.md) |
| Writing or updating docs | [Documentation standard](docs/DOCUMENTATION_STANDARD.md), [Architecture docs standard](docs/architecture/ARCHITECTURE_DOCS_STANDARD.md) |

## Repository layout

| Path | Content |
|---|---|
| `build.sh`, `update.sh` | The build and update scripts |
| `compose/docker-compose.<profile>.yml` | One fragment per build profile |
| `scripts/common/` | Helpers sourced by the scripts |
| `scripts/backup_restore/`, `scripts/remote/`, `scripts/offline/`, `scripts/import-ssl-cert.sh` | Operational tooling; how-tos under `docs/how-to/` |
| `scripts/docs/` | Documentation generators and their data files |
| `credentials/` | Templates for certbot credentials and TLS files (real files are gitignored) |
| `record_cli.py`, `stitch_cli.py` | CLI scripts mounted into the `tools` profile services |
| `scv2_base_images/` | Shared base images used by other Pacefactory repos ([README](scv2_base_images/README.md)) |
| `docs/` | All documentation ([index](docs/README.md)) |

macOS: `./build.sh` delegates to `scripts/build-mac.sh`, a containerised build
for developers; it is not a supported production path.
