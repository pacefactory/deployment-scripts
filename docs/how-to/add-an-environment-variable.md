---
title: Add an environment variable
type: how-to
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
  - scripts/docs/render-env-reference.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Add an environment variable

## Goal

Expose a new build-time variable that reaches a service, with a prompt and a
default, and update the reference.

## Prerequisites

- [ ] The fragment that owns the service (`compose/docker-compose.<profile>.yml`).
- [ ] `<VAR>` name (upper snake case), its default, and the container variable or compose key it must reach.

## Steps

1. Declare it under `x-pf-info.settings` in the fragment:

   ```yaml
   x-pf-info:
     settings:
       <VAR>:
         default: <DEFAULT>
         description: <one line shown in the prompt>
   ```

   Add `hidden: true` for a value that must be written without a prompt, or
   `default_var: <OTHER_VAR>` to take the prompt default from another variable.

2. Interpolate it in the service with the same default as fallback, so the
   built file is correct even when the variable is absent from `.env`:

   ```yaml
   services:
     <service>:
       environment:
         - "<CONTAINER_VAR>=${<VAR>:-<DEFAULT>}"
   ```

   Use `${<VAR>:?message}` only when there is no sensible default (pattern in
   `compose/docker-compose.mqtts-public.yml:22`).

3. Regenerate the environment variable reference and the profile page:

   ```bash
   ./scripts/docs/regenerate.sh
   ```

   If a reference deployment should exercise a non-default value, edit its
   `.env` under `docs/architecture/reference-deployments/<name>/` first; the
   regenerate step rebuilds it.

4. Document the variable's semantics in the owning service repo's
   configuration reference; this repo only records where the value reaches.

## Verify

`docs/reference/environment-variables.md` lists `<VAR>` under the profile with
kind `setting` (or `hidden setting`), the exact default, and
`<service>.environment=<CONTAINER_VAR>` in "Reaches service(s) as".
`./build.sh -q` followed by `grep <CONTAINER_VAR> docker-compose.yml` shows the
default.

## Rollback

Remove the setting and interpolation, regenerate. A stale value left in a
site's `.env` is harmless once nothing interpolates it.

## Related

- [Profile metadata reference](../reference/profile-metadata.md)
- [Environment variable reference](../reference/environment-variables.md)
