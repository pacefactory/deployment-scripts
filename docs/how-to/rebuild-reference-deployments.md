---
title: Rebuild the reference deployments and regenerate docs
type: how-to
derived_from:
  - scripts/docs/build-reference-deployment.sh
  - scripts/docs/regenerate.sh
  - scripts/docs/check-docs.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Rebuild the reference deployments and regenerate docs

## Goal

Bring every generated document, diagram and committed build output back in
line with the fragments and `build.sh`, and prove there is no drift.

## Prerequisites

- [ ] mikefarah `yq` v4 on PATH; docker compose plugin (no daemon needed).
- [ ] No `compose/docker-compose.custom.yml` in the checkout (the wrapper refuses to run with one).
- [ ] Optional, for diagram validation: `mmdc` from `@mermaid-js/mermaid-cli` and a Chromium the `--mermaid` check can use.
- [ ] Your own `.env`, `.settings` and `docker-compose.yml` are backed up by the wrapper and restored; nothing else in the root is touched.

## Steps

1. Check for drift without writing anything under `docs/`:

   ```bash
   ./scripts/docs/regenerate.sh --check
   ```

   Exit code 1 and a diff mean a fragment or `build.sh` changed since the
   reference outputs were committed.

2. Regenerate everything (rebuild the six reference deployments, then the
   glossary, profile pages and catalog, environment variable reference,
   profile dependencies, deployment pages and their diagrams, the index):

   ```bash
   ./scripts/docs/regenerate.sh
   ```

3. Review `git diff docs/` and commit the result together with the code
   change that caused it.

To rebuild one deployment only:

```bash
./scripts/docs/build-reference-deployment.sh <NAME>
./scripts/docs/render-deployment-page.sh <NAME>
```

To add a reference deployment: create
`docs/architecture/reference-deployments/<NAME>/.settings` (a bash
`declare -A SCV2_PROFILES=(...)` line plus `declare -- PROJECT_NAME="deployment-scripts"`)
and `.env` (at least the two pinned `MONGO_*` values), add a row to
`scripts/docs/deployments.tsv` naming a request-flow template, then run the
two commands above.

## Verify

```bash
./scripts/docs/check-docs.sh            # headers, index coverage, derived_from paths
./scripts/docs/check-docs.sh --mermaid  # every .mmd and embedded diagram parses (needs mmdc)
./scripts/docs/regenerate.sh --check    # built outputs match the committed files
git status --short                      # nothing outside docs/ and scripts/docs/ changed
```

## Rollback

`git checkout -- docs/` discards a regeneration.

## Related

- [Architecture docs standard §2 and §10](../architecture/ARCHITECTURE_DOCS_STANDARD.md)
- [Reference deployments](../architecture/reference-deployments/README.md)
