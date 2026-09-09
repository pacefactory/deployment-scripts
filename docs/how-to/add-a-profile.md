---
title: Add a profile
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
  - scripts/docs/regenerate.sh
  - scripts/docs/services.tsv
  - scripts/docs/flows.tsv
last_verified: 2026-09-09
verified_against: ccf3768
---

# Add a profile

## Goal

Add a new build profile (compose fragment) that `build.sh` offers, and update
the derived documentation in the same change.

## Prerequisites

- [ ] `<PROFILE_ID>`: lowercase, digits and hyphens; it becomes the file name and the `--<PROFILE_ID>` flag.
- [ ] The services, images and settings the profile adds.
- [ ] mikefarah `yq` v4 and docker compose for regenerating docs.

## Steps

1. Create `compose/docker-compose.<PROFILE_ID>.yml` with an `x-pf-info` block
   ([schema](../reference/profile-metadata.md)) and the services. Every new
   service needs `container_name: ${PROJECT_PREFIX:-}<name>`,
   `hostname: ${PROJECT_PREFIX:-}<name>`, `restart: always`,
   `logging: {driver: local}` and a network, following the existing fragments.
   Use `x-pf-info.required-profiles` when the profile needs another one, and
   `sub-profile: true` plus a parent `sub-profiles` entry for a variant.

2. If the apigateway must route to the new service, add an override block for
   `apigateway` with `SCV2_PROFILE_<NAME>=true` and the host/port variables the
   gateway expects (pattern in `compose/docker-compose.rdb.yml:29-35`). The
   gateway side is owned by scv2_apigateway.

3. Register each new service in `scripts/docs/services.tsv` (node ID, image,
   owning repo, one-sentence purpose) and every flow it originates or
   terminates in `scripts/docs/flows.tsv`, citing the fragment lines. Add a
   row to `scripts/docs/externals.tsv` and a page under
   `docs/architecture/integrations/` if it talks to a new class of external
   system.

4. Build once to confirm the fragment merges:

   ```bash
   ./build.sh -q --<PROFILE_ID> && docker compose config --services | grep <service>
   ```

5. Regenerate the docs and add the profile to any reference deployment that
   should include it:

   ```bash
   ./scripts/docs/regenerate.sh
   ```

6. Add the new files to `scripts/docs/index.tsv` if they are not in a
   generated tree, then `./scripts/docs/render-docs-index.sh`.

## Verify

```bash
./scripts/docs/check-docs.sh
```

passes, `docs/architecture/profiles/<PROFILE_ID>.md` exists and its
Inputs / Outputs table is not empty (or says the profile is configuration
only).

## Rollback

Delete the fragment and the data rows, regenerate.

## Related

- [Profile metadata reference](../reference/profile-metadata.md)
- [Add an environment variable](add-an-environment-variable.md)
- [Architecture docs standard §10](../architecture/ARCHITECTURE_DOCS_STANDARD.md#10-change-triggers)
