# Deployment Scripts

Deployment tooling for Pacefactory: `build.sh` assembles the compose fragments
under `compose/` into `docker-compose.yml` according to `.settings` and `.env`;
`update.sh` pulls and relaunches. Facts about the scripts, profiles, variables
and services live in `docs/` (start at `docs/README.md`), not here.

This repo owns the canonical documentation standards and the cross-repo
architecture documentation for all Pacefactory repositories.

## Documentation
- Follow `docs/DOCUMENTATION_STANDARD.md` for all docs work. This repository holds the canonical copy; service repos carry copies produced by `scripts/docs/sync-standard.sh`.
- Before writing or editing a doc, read the files listed in its `derived_from` header.
- Never state a fact you cannot point to in the repo. Write `TODO(source): …` instead.
- When asked to "update docs", first produce a list of discrepancies between the doc and its `derived_from` sources, then apply fixes. Report both.
- When code you change affects a doc (search `docs/` for the changed symbol, path, flag, env var, or schema field), update that doc in the same change and bump `last_verified`.
- When you add or change a data or config type the service produces, add or update its file under `docs/reference/schemas/`.
- Diagrams are Mermaid; edit the `.mmd` source and the embedded copy together, or regenerate both when they are generated.
- Do not create docs that are not listed in `docs/README.md`; add the entry.
- Use the vocabulary and node IDs from the deployment-scripts glossary.

## Architecture documentation
- Follow `docs/architecture/ARCHITECTURE_DOCS_STANDARD.md`. It extends the service-repo standard.
- System-level diagrams are derived from *built* compose output, never from fragments. To update one, run `scripts/docs/build-reference-deployment.sh <name>` (it runs build.sh with the deployment's recorded `.env` / `.settings`), then `scripts/docs/regenerate.sh`.
- `build.sh` is universal. Never create per-deployment build scripts; the only wrapper is `scripts/docs/build-reference-deployment.sh`. Record inputs instead.
- Generated docs (profile pages and catalog, glossary, environment variable reference, profile dependencies, reference deployment pages and diagrams, `docs/README.md`, `docs/architecture/README.md`) are never hand-edited. Edit the generator or its data file in `scripts/docs/` and regenerate.
- Every service in a topology diagram must also appear in the flow table and `data-flows.mmd` with at least one input or output. If you cannot find any, add a `flows.tsv` row with `TODO(source)` rather than omitting the service.
- External systems use `ext_*` IDs from `scripts/docs/externals.tsv`. If an integration type has no ID, add the row and a skeleton `integrations/<type>.md` first.
- Record flows at the network level (direction, protocol, channel) with the fragment line that evidences them. Link to the service repo for payload schemas and integration internals; do not copy them here.
- Use the Mermaid node IDs in `docs/architecture/glossary.md`. Do not invent IDs. If a service has no ID, add it to `services.tsv` first.
- Every arrow in a system-level diagram is labelled with protocol and purpose. Validate diagrams with `scripts/docs/check-docs.sh --mermaid`.
- Do not describe service internals here. Link to `<service repo>/docs/architecture/README.md`.
- Optional-profile services are drawn dashed and labelled with their home profile.
- `build.sh` needs mikefarah `yq` v4 on PATH; the Python `yq` wrapper silently breaks the profile loop.

## Repo-specific overrides
- This repository is not a service: no API reference and no data/config schema reference apply. Its required documents are those listed in the architecture standard §3.
- Terminology: "profile" means build profile (a fragment `build.sh` can enable); Docker Compose's own `profiles:` key is called "compose profile". Both are defined in `docs/architecture/glossary.md`.
- The `custom` profile is forced by `build.sh` but its fragment is gitignored and absent from the repo; a site supplies it. It merges after `base` and before every later fragment alphabetically.
- Reference deployment inputs pin the project name (`deployment-scripts`), the checkout path (`/home/pacefactory/scv2/git_clones/deployment-scripts`) and mongo sizing (`4g` / `1.5`) so builds are reproducible; keep those pins when adding one.
- Client network requirements are a carve-out (`docs/architecture/network/`); only facts evidenced in this repo go there until the external requirements deck has been reconciled.
- Before pushing a docs change run `scripts/docs/check-docs.sh` and `scripts/docs/regenerate.sh --check`.

## Commands
- Build: `./build.sh` (interactive) or `./build.sh -q` (quiet). Update: `./update.sh`.
- Regenerate docs: `./scripts/docs/regenerate.sh`; drift check: `./scripts/docs/regenerate.sh --check`.
- Push the documentation standard to service repos: `./scripts/docs/sync-standard.sh <checkout>...`; verify with `--check`.
