---
title: "Profile: expresso-020-cuda"
type: reference
derived_from:
  - compose/docker-compose.expresso-020-cuda.yml
  - build.sh
  - scripts/docs/flows.tsv
  - scripts/docs/services.tsv
last_verified: 2026-09-10
verified_against: ba84b53
---

# Profile: `expresso-020-cuda`

**Display name:** Expresso CUDA

Should Expresso run with GPU support

| Attribute | Value |
|---|---|
| Fragment | `compose/docker-compose.expresso-020-cuda.yml` |
| Class | sub-profile of expresso-010, default off |
| Prompt | Enable CUDA for Expresso? |
| Parent profile(s) | [`expresso-010`](expresso-010.md) |
| Sub-profiles | none |
| Requires (`required-profiles`) | none |
| Required by | none |
| Conflicts with (inferred) | none found |

## Services added

None. This profile only modifies services from other profiles.

## Services modified from other profiles

| Service | Home profile | Keys this profile adds or overrides |
|---|---|---|
| `celery_worker` | [`expresso-010`](expresso-010.md) | deploy, environment |

## Networks and volumes added

- Networks: none
- Named volumes: none

## Settings (`x-pf-info.settings`)

| Variable | Default (as written) | Hidden | default_var | Description |
|---|---|---|---|---|
| `EXPRESSO_SERVER_TAG_DEFAULT_GPU` | `latest-gpu` | true |  | (none in fragment) |

See the [environment variable reference](../../reference/environment-variables.md) for where each value reaches.

## Inputs / Outputs

Flows this profile originates or terminates. Node IDs are defined in the [glossary](../glossary.md).

None. This profile changes configuration only; it adds no flow of its own.

## Diagram

Source: [`expresso-020-cuda.mmd`](expresso-020-cuda.mmd). Dashed boxes are services from optional profiles; hexagons are external systems.

```mermaid
flowchart LR
  classDef optional stroke-dasharray: 5 5
  subgraph deployment["services touched by profile expresso-020-cuda"]
  end
```
