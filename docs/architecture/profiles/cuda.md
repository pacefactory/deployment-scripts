---
title: Profile: cuda
type: reference
derived_from:
  - compose/docker-compose.cuda.yml
  - build.sh
  - scripts/docs/flows.tsv
  - scripts/docs/services.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# Profile: `cuda`

**Display name:** Realtime CUDA

Should Realtime run with GPU (CUDA) support?

| Attribute | Value |
|---|---|
| Fragment | `compose/docker-compose.cuda.yml` |
| Class | sub-profile of base, default off |
| Prompt | Enable CUDA for Realtime? |
| Parent profile(s) | [`base`](base.md) |
| Sub-profiles | none |
| Requires (`required-profiles`) | none |
| Required by | none |
| Conflicts with (inferred) | none found |

## Services added

None. This profile only modifies services from other profiles.

## Services modified from other profiles

| Service | Home profile | Keys this profile adds or overrides |
|---|---|---|
| `realtime` | [`base`](base.md) | deploy, environment |

## Networks and volumes added

- Networks: none
- Named volumes: none

## Settings (`x-pf-info.settings`)

| Variable | Default (as written) | Hidden | default_var | Description |
|---|---|---|---|---|
| `REALTIME_TAG_DEFAULT_GPU` | `latest-gpu` | true |  | (none in fragment) |

See the [environment variable reference](../../reference/environment-variables.md) for where each value reaches.

## Inputs / Outputs

Flows this profile originates or terminates. Node IDs are defined in the [glossary](../glossary.md).

None. This profile changes configuration only; it adds no flow of its own.

## Diagram

Source: [`cuda.mmd`](cuda.mmd). Dashed boxes are services from optional profiles; hexagons are external systems.

```mermaid
flowchart LR
  classDef optional stroke-dasharray: 5 5
  subgraph deployment["services touched by profile cuda"]
  end
```
