# Pacefactory Documentation Standard (Service Repos)

Version: 0.1-draft
Applies to: every Pacefactory service repository. Cross-repo architecture
documentation is governed separately by the deployment-scripts
`ARCHITECTURE_DOCS_STANDARD.md`.

This document is written for both humans and AI assistants (Claude Code).
Every rule is phrased so that compliance can be checked against the repo.

---

## 1. Principles

1. **Docs live next to their source of truth.** Anything derived from this
   repo's code is documented in this repo. Nothing about *other* repos is
   documented here except by link.
2. **Derive, don't invent.** Every factual claim (endpoint, flag, path, port,
   env var, default) must be traceable to a file in this repo. If the source
   is silent, write `TODO(source): <what is missing>` rather than guessing.
3. **Text over images.** Diagrams are Mermaid source committed to the repo.
   No binary diagram files unless a Mermaid equivalent is impossible.
4. **Link, never copy.** Content owned by another repo is referenced by URL
   to that repo's `docs/`. Copied content goes stale and is prohibited.
5. **One idea per doc.** A doc is a reference, a how-to, or an example. It
   is not more than one of these.

---

## 2. Repository layout

```
<repo>/
  README.md                  # what this service is, how to run it locally, link to docs/
  CLAUDE.md                  # AI assistant instructions; MUST link to this standard + repo overrides
  docs/
    README.md                # index of every doc below with a one-line purpose each
    reference/               # code-derived facts (API, config, CLI, data/config schemas)
    how-to/                  # one task per file, imperative titles
    architecture/            # service-internal diagrams (.mmd) + a README mapping each to its source
    examples/                # optional; end-to-end examples, no prescribed structure
```

Repos may add other folders under `docs/` (design notes, decision records,
etc.) as they see fit. Only `reference/`, `how-to/`, and `architecture/` are
required, and only those have prescribed structure.

- `docs/README.md` is the only place that lists docs. Every file under
  `docs/` must appear there. Nothing else in the repo lists docs.
- Filenames: `kebab-case.md`. How-to files start with a verb:
  `rotate-tls-certificate.md`, not `tls-certificate-rotation.md`.
- Diagram sources use the `.mmd` extension and are also embedded (as a
  Mermaid code block) in the doc that explains them, so GitHub renders both.

---

## 3. Required documents

Every service repo MUST contain at least:

| Doc | Location | Notes |
|---|---|---|
| Service overview | `README.md` | Purpose, where it sits in the system (one sentence + link to deployment-scripts architecture docs), local dev quickstart. |
| Configuration reference | `docs/reference/configuration.md` | Every env var / config key the service reads. See §5.1. |
| API reference (if the service exposes one) | `docs/reference/api.md` | Derived from the OpenAPI spec or router definitions. See §5.1. |
| Data / config schema reference (if the service produces any) | `docs/reference/schemas/*.md` | Structure of every data type or config type the service generates. See §5.1. |
| Operations how-to | `docs/how-to/*.md` | At minimum: view logs, restart safely, common failure and recovery. |
| Internal architecture | `docs/architecture/README.md` + `.mmd` | At minimum one component/flow diagram. See §6. |
| Docs index | `docs/README.md` | See §2. |

Optional docs (examples, design notes, and anything else a repo adds) follow
the header (§4) and style (§7) rules but have no prescribed structure.

---

## 4. Document header

Every file under `docs/` begins with this block:

```markdown
---
title: <Title>
type: reference | how-to | example | other
derived_from:
  - <repo-relative path or glob the content is derived from>
last_verified: YYYY-MM-DD
verified_against: <git short SHA or tag>
---
```

- `derived_from` is mandatory and must list real paths. A doc with no
  derivable source (e.g., a design note) lists the files it *explains*.
- `last_verified` / `verified_against` are updated whenever someone (or an
  automated job) re-checks the doc against the code, even if nothing changed.
- These fields exist so that drift can be detected mechanically later. Do not
  remove them.

---

## 5. Rules by document type

### 5.1 Reference docs

- Reference docs describe *what is*, never *how to* or *why*.
- Tables are preferred. Every row must be traceable to `derived_from`.
- **Configuration reference** columns: `Variable | Type | Default | Required | Description | Read in`. `Read in` is the file that consumes it.
  Defaults must be quoted exactly as they appear in code. If the code has no default, the cell says `none`, not blank.
- **API reference**: one section per endpoint with `Method + path`, auth requirement, request schema, response schema, error responses, and exactly one working `curl` example. Schemas are derived from the FastAPI/Pydantic models or OpenAPI output; field names must match exactly.
  If the repo already publishes OpenAPI, `api.md` links to it and documents only what OpenAPI cannot express (auth flow, pagination conventions, rate limits, examples).
- **Data and config schema reference**: if the service *generates* a type of data or config (records written to a database or message bus, files written to disk, exported reports, config files it emits for other services, etc.), the structure of each such type is documented, one file per type under `docs/reference/schemas/`. Each file states:
  - what produces it (module/function) and what consumes it (service, table, topic, path), with links where the consumer is another repo;
  - the full field/key list as a table: `Field | Type | Required | Description | Set by`, derived from the model, schema, or serialiser in code — field names must match exactly;
  - versioning or compatibility rules if the type is versioned;
  - one minimal real example of the data or config.
  If a machine-readable schema already exists (Pydantic model, JSON Schema, protobuf, SQL DDL), the doc links to it and documents only what the schema cannot express. Do not transcribe a schema that code already defines.

### 5.2 How-to guides

- Title is a task in the imperative: "Rotate the TLS certificate".
- Structure, in order: **Goal** (one sentence) → **Prerequisites** (as a checklist) → **Steps** (numbered) → **Verify** (how to prove it worked) → **Rollback** (if applicable) → **Related**.
- Every command is shown in a fenced code block with the shell named (` ```bash `). Commands must be copy-pasteable; placeholders use `<ANGLE_BRACKETS>` and are listed under Prerequisites.
- Every step that behaves differently on RHEL vs Ubuntu is marked with a callout:
  `> **RHEL:** …` / `> **Ubuntu:** …`. Untagged steps are asserted to work on both.
- Steps that require elevated privileges, network egress, or a proxy must say so explicitly, because most client sites are locked down.
- **Verify** is mandatory. A how-to without a verification step is incomplete.

### 5.3 Examples

- Optional. No prescribed structure beyond the header (§4).
- Use only commands and features that exist in the repo at `verified_against`. No aspirational features.
- Reference the how-to and reference docs they exercise rather than duplicating steps or tables.

---

## 6. Diagrams

- Format: **Mermaid** (`flowchart`, `sequenceDiagram`, `C4Context`/`C4Container`, `stateDiagram-v2`). Use D2 or PlantUML only with a written justification in `docs/architecture/README.md`.
- `docs/architecture/README.md` contains a table: `Diagram file | What it shows | Derived from | Last verified`.
- Node IDs are stable identifiers, not display labels, so diffs stay readable: `api_gateway["API Gateway (nginx)"]`, not `A["API Gateway"]`. Reuse the same ID for the same component across every diagram in the repo.
- Every box in a component diagram must correspond to something real in `derived_from` (a module, container, external system). Every arrow must be a real call, message, or data flow, labelled with protocol or purpose where it is not obvious.
- Do not encode meaning in colour alone; use shape or label as well.
- Diagram scope: service-internal only. The service's place in the overall system is one box in the deployment-scripts architecture diagrams; link to those rather than redrawing them.

---

## 7. Style and terminology

- Product name is **Pacefactory**. Do not abbreviate in docs.
- Deployment vocabulary (use consistently; see deployment-scripts glossary for the authoritative list): *site* (a physical client location), *deployment* (one running compose stack), *profile* (a compose fragment selected when `build.sh` builds a deployment), *service* (one container in a deployment).
- Second person, present tense, active voice. "Run the script", not "The script should be run".
- No marketing language. No "simply", "just", "easily".
- Prefer short paragraphs and lists over long prose. Use tables for anything with more than two attributes.
- Dates are ISO 8601. Paths are absolute where the doc is operational, repo-relative where it is about code.
- Redact real hostnames, IPs, credentials, and client identifiers unless the doc is explicitly client-specific and lives in a client-specific location.

---

## 8. AI assistant instructions (for `CLAUDE.md`)

Include this block in every service repo's `CLAUDE.md`, then add repo-specific overrides below it.

```markdown
## Documentation
- Follow `docs/DOCUMENTATION_STANDARD.md` (or the linked canonical copy) for all docs work.
- Before writing or editing a doc, read the files listed in its `derived_from` header.
- Never state a fact you cannot point to in the repo. Write `TODO(source): …` instead.
- When asked to "update docs", first produce a list of discrepancies between the doc and its `derived_from` sources, then apply fixes. Report both.
- When code you change affects a doc (search `docs/` for the changed symbol, path, flag, env var, or schema field), update that doc in the same change and bump `last_verified`.
- When you add or change a data or config type the service produces, add or update its file under `docs/reference/schemas/`.
- Diagrams are Mermaid; edit the `.mmd` source and the embedded copy together.
- Do not create docs that are not listed in `docs/README.md`; add the entry.
```

### Repo-specific overrides

Each repo adds a short section to its `CLAUDE.md` with only what differs:

- Additional required docs for this service.
- Service-specific terminology or acronyms.
- Which sections of this standard do not apply and why (e.g., "no API reference; this service exposes no HTTP API", "no schema reference; this service produces no data or config").
- Location of the OpenAPI spec, if any.

Overrides may tighten this standard. They may not loosen §1 (principles),
§4 (headers), or §6 node-ID rules.

---

## 9. Review checklist

Before merging a docs change, confirm:

- [ ] Header present and `derived_from` paths exist.
- [ ] Every command, flag, path, port, env var, schema field, and default appears in a `derived_from` source.
- [ ] Every data/config type the service produces has a schema reference doc.
- [ ] No content copied from another repo; links used instead.
- [ ] How-to has Goal, Prerequisites, Steps, Verify.
- [ ] RHEL/Ubuntu differences are tagged.
- [ ] Diagram node IDs are stable and match other diagrams in the repo.
- [ ] `docs/README.md` index updated.
- [ ] `last_verified` and `verified_against` updated.

---

## 10. Changing this standard

This file is versioned. Changes are proposed as a PR to its canonical
location (TBD: deployment-scripts or a dedicated `pacefactory/docs` repo) and
announced to repo owners. Service repos reference the canonical copy by URL
in `CLAUDE.md` rather than vendoring it, so a change applies everywhere at
once.
