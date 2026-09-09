---
title: "Profile metadata (x-pf-info)"
type: reference
derived_from:
  - build.sh
  - compose/docker-compose.ape.yml
  - compose/docker-compose.audit-perf-eval.yml
  - compose/docker-compose.autozone.yml
  - compose/docker-compose.base.yml
  - compose/docker-compose.cuda.yml
  - compose/docker-compose.expresso-010.yml
  - compose/docker-compose.expresso-020-cuda.yml
  - compose/docker-compose.expresso-030-trainer.yml
  - compose/docker-compose.https-digitalocean.yml
  - compose/docker-compose.https-godaddy.yml
  - compose/docker-compose.https-manual.yml
  - compose/docker-compose.https-no-certbot.yml
  - compose/docker-compose.mqtt-public.yml
  - compose/docker-compose.mqtts-public.yml
  - compose/docker-compose.node-red.yml
  - compose/docker-compose.ntfy.yml
  - compose/docker-compose.offline.yml
  - compose/docker-compose.rdb.yml
  - compose/docker-compose.service-ports.yml
  - compose/docker-compose.social.yml
  - compose/docker-compose.swift-labeler.yml
  - compose/docker-compose.tools.yml
last_verified: 2026-09-09
verified_against: ccf3768
---

# Profile metadata (`x-pf-info`)

Each fragment `compose/docker-compose.<id>.yml` may carry an `x-pf-info`
extension block that tells `build.sh` how to prompt for the profile and its
settings. `docker compose config` merges the blocks of all enabled fragments
into the output, where they are inert. This page documents every key
`build.sh` reads.

## Keys

| Key | Type | Read at | Effect |
|---|---|---|---|
| `name` | string | `build.sh:313-314, 201-202, 277-278` | Display name in prompts and " -> Will enable …" lines. Defaults to the profile id. |
| `prompt` | string | `build.sh:316-317, 206-207` | Prompt text. Defaults to `Enable <name>?`. |
| `description` | string | `build.sh:342-343, 228-229` | Shown when the user answers `?`. |
| `sub-profile` | bool | `build.sh:308-311` | `true` skips the fragment in the main loop; it is offered only via a parent's `sub-profiles`. |
| `sub-profiles` | list of ids | `build.sh:190` | Prompted immediately after this profile is enabled, before this profile's settings, so their hidden settings can change this profile's prompt defaults. |
| `required-profiles` | list of ids | `build.sh:259` | Force-enabled without a prompt when this profile is enabled; a required profile already passed over is enabled retroactively. |
| `settings.<VAR>.default` | scalar | `build.sh:146` | Prompt suggestion and the value written for hidden settings. Quoted exactly in the [environment variable reference](environment-variables.md). |
| `settings.<VAR>.default_var` | variable name | `build.sh:149,156-159` | If that variable currently has a value, it replaces `default` as the suggestion. Used to let a CUDA sub-profile switch a tag default to `latest-gpu`, and to surface the RAM-scaled mongo defaults. |
| `settings.<VAR>.description` | string | `build.sh:150,169` | Shown in the prompt. |
| `settings.<VAR>.hidden` | bool | `build.sh:154,162-166` | `true`: never prompted; the default is assigned and written to `.env` whenever the profile is enabled. |

Settings are prompted in key order as `yq` returns them (alphabetical).

## Example

`compose/docker-compose.expresso-010.yml` (parent) and
`compose/docker-compose.expresso-020-cuda.yml` (sub-profile) show the pattern:
the parent declares `EXPRESSO_SERVER_TAG` with `default: latest` and
`default_var: EXPRESSO_SERVER_TAG_DEFAULT_GPU`; the sub-profile declares the
hidden setting `EXPRESSO_SERVER_TAG_DEFAULT_GPU: latest-gpu`; the service image
reads `${EXPRESSO_SERVER_TAG:-${EXPRESSO_SERVER_TAG_DEFAULT_GPU:-latest}}`.
Enabling the sub-profile therefore changes both the prompt default and the
compose fallback.

## Not metadata

`services.<name>.profiles` (a list containing the profile id) is Docker
Compose's own [compose profile](../architecture/glossary.md#compose-profile)
mechanism. In this repository it marks on-demand services (`record_video`,
`stitch_videos`, `certbot`) so `docker compose up` does not start them; they run
with `docker compose run --rm <service>`. It works because `build.sh` passes
`--profile <id>` for every enabled build profile.

Related: [Add a profile](../how-to/add-a-profile.md),
[Add an environment variable](../how-to/add-an-environment-variable.md),
[Profile catalog](../architecture/profiles/README.md).
