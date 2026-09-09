# Pacefactory Cross-Repo Architecture Documentation Standard

Version: 0.1-draft
Lives in: `deployment-scripts/docs/architecture/`
Extends: the service-repo `DOCUMENTATION_STANDARD.md`. All rules there apply
here unless this document says otherwise.

---

## 1. Purpose and scope

deployment-scripts owns the documentation of **how Pacefactory services are
composed into a deployment**. That includes:

- what profiles exist, which are required, which are optional, and how they combine
- which services each profile contributes, and how those services are networked
- the **network and data flow inputs and outputs** of every service and every
  external integration: what each service receives, from where, over what
  protocol, and what it emits, to where (see §7a)
- every environment variable the build script accepts, and what it changes
- named reference deployments and their diagrams
- the on-premises network shape a deployment expects at a client site

It does **not** document the internals of any service. Those live in the
service's own repo under `docs/architecture/`. This repo links to them.

Ownership boundary, stated once:

| Question | Owned by |
|---|---|
| What does service X do internally? | Service X repo |
| What env vars does service X read? | Service X repo (`docs/reference/configuration.md`) |
| What env vars does the *build script* accept, and which service does each one reach? | **This repo** |
| Which services run together, on which networks, with which ports exposed? | **This repo** |
| How does a request flow between services? | **This repo** (inter-service); service repo (intra-service) |
| What does service X take in and put out (protocols, endpoints, topics, tables, files)? | **This repo** (the flow map, §7a); service repo (message formats, schemas, protocol details) |
| How does the deployment talk to a 3rd-party system (cameras, MES, MQTT broker, OPC server)? | **This repo** (which service, which direction, which protocol); service repo (integration internals) |
| What does the client network need to look like? | **This repo** |

---

## 2. Source of truth

Because the compose file is *built* by `build.sh`, the source of truth is layered.
Every doc in this folder must name which layer it derives from:

1. **Profile definitions** — the fragments the build script assembles.
   Source for: profile catalog, per-profile service lists, profile dependencies.
2. **Build script (`build.sh`) and its defaults** — the universal script
   that assembles fragments and resolves env vars for every deployment.
   Source for: env var reference, required/optional classification, validation rules.
3. **Built output** — the `docker-compose.yml` produced by `build.sh` for a
   specific profile set and env.
   Source for: reference-deployment topology diagrams. Diagrams are drawn
   from the *output*, never hand-assembled from fragments, so that build
   script behaviour (merges, overrides, conditional services) is reflected.
4. **Service repo docs** — each service's `docs/reference/` and
   `docs/architecture/`.
   Source for: the *details* of a service's inputs and outputs (message
   formats, schemas, endpoint lists). This repo records that a flow exists,
   its direction and protocol; it links to the service repo for the rest.

Rule: if a doc's `derived_from` lists only fragments but describes a whole
deployment, it is wrong. Rebuild and re-derive from output.

Rule: the repo keeps the exact `build.sh` invocation (profile selection and
env file) used to produce each reference deployment (see §4) so anyone,
including an AI assistant, can reproduce the output and re-derive the diagram.

---

## 3. Directory layout

```
deployment-scripts/
  CLAUDE.md
  docs/
    README.md                          # index (per service-repo standard)
    architecture/
      README.md                        # this folder's index: diagram | shows | derived from | last verified
      glossary.md                      # authoritative deployment vocabulary (see §7)
      system-context.mmd               # Pacefactory as one system + external actors/systems
      profiles/
        README.md                      # profile catalog table (see §5)
        <profile-name>.md              # one per profile; embeds <profile-name>.mmd
        <profile-name>.mmd             # services, networks, and in/out flows contributed by this profile
      reference-deployments/
        README.md                      # table of named deployments (see §4)
        <deployment-name>/
          build.env                    # env file passed to build.sh
          build.args                   # profile selection / flags passed to build.sh (exact command recorded in README)
          docker-compose.built.yml     # committed build.sh output, rebuilt on change
          topology.mmd                 # container topology derived from the output
          data-flows.mmd               # inputs/outputs map: internal + external (see §7a)
          request-flows.mmd            # inter-service sequence diagram(s)
          README.md                    # what this variant is for, exact build.sh command, embeds the diagrams
      integrations/
        README.md                      # catalogue of 3rd-party integration types (see §7a)
        <integration-type>.md          # one per type: cameras-rtsp.md, mes-rest.md, mes-sql.md, mqtt.md, opc.md, ...
      network/
        site-requirements.md           # client network requirements (existing doc moves/links here)
        site-network.mmd               # on-prem network diagram: proxy, DNS, AD, Teleport, egress
    reference/
      environment-variables.md         # every build.sh env var (see §6)
      profile-dependencies.md          # which profiles require/conflict with which
    how-to/
      build-a-deployment.md
      add-a-profile.md
      add-an-environment-variable.md
      ...
```

---

## 4. Reference deployments

A **reference deployment** is a named, committed combination of profiles and
env values that represents a real class of installation.

- Maintain a small set (target: 3–6). Examples of the *kind* of thing that
  qualifies: minimal (required profiles only), a full-featured default, a
  GPU-enabled variant, a locked-down-network variant. Choose names that
  describe the variant, not the client.
- Each has its `build.env` and `build.args` (the inputs to `build.sh`), the
  exact `build.sh` command recorded in its README, the committed built compose
  file, and diagrams derived from that file. `build.sh` itself is universal
  and lives once at the repo root; reference deployments never carry a copy
  or a wrapper of it.
- Diagrams for reference deployments are the **only** system-level topology
  diagrams. There is no hand-maintained "master" diagram of every possible
  service; it would be wrong by construction because profiles are optional.
- The built compose file is committed so that the diagram's
  `derived_from` points at a real file in the repo and drift is diffable.
  It is marked as build output at the top and is never edited by hand.
- `reference-deployments/README.md` columns:
  `Name | Purpose | Profiles included | Notable env overrides | Diagrams`.

---

## 5. Profile catalog

`profiles/README.md` is the authoritative list. Columns:

`Profile | Required? | Services added | Networks/volumes added | External integrations enabled | Depends on | Conflicts with | Owning service repo(s) | Doc`

Rules:

- Every profile the build script knows about appears here. The catalog is
  derived from profile definitions; a profile in code but not in the catalog
  is a docs defect.
- Each profile has its own page embedding a small `.mmd` showing only what
  that profile *adds*: its services, the networks they join, the services
  from other profiles they talk to (drawn as dashed boxes, labelled with the
  contributing profile), and any external systems its services connect to
  (drawn as hexagons, see §7).
- Each profile page has an **Inputs / Outputs** table (same columns as §7a)
  listing every flow its services originate or terminate.
- Profile pages link to each service's own repo for internals. They do not
  describe what the service does beyond one sentence.

---

## 6. Environment variable reference

`reference/environment-variables.md` documents every variable the
**build script** accepts. Columns:

`Variable | Type | Default | Required | Profiles affected | Reaches service(s) as | Description | Defined in`

- `Default` is quoted exactly from `build.sh` (or the files it sources); `none` if there is no default.
- `Profiles affected` lists which profiles change behaviour when this is set;
  `all` if global.
- `Reaches service(s) as` names the container-side variable(s) or config the
  value becomes, so a reader can follow it into the service repo's own
  configuration reference. Link to that reference.
- Variables that only a service reads (and the build script passes through
  untouched) are listed once with `Reaches service as: passthrough` and a link;
  their semantics are documented in the service repo, not here.
- Group by profile, then alphabetically. Required variables first within a
  group.

---

## 7. Diagram rules (in addition to the service-repo standard)

**Stable IDs across the whole repo.** Every service has exactly one Mermaid
node ID, defined in `glossary.md` alongside its display name and owning repo.
All diagrams in this repo use that ID. Service repos are encouraged to use the
same ID for their "self" box.

**Visual conventions** (shape + label, never colour alone):

| Element | Mermaid shape | Label convention |
|---|---|---|
| Pacefactory service (this deployment) | rectangle `id["Name"]` | display name from glossary |
| Service from an optional profile | rectangle with dashed style, `classDef optional stroke-dasharray` | `Name (profile: <p>)` |
| Data store / volume | cylinder `id[("Name")]` | name + persistence note |
| External system / 3rd-party integration | hexagon `id{{"Name"}}` | glossary integration-type ID and display name, e.g. `ext_cameras{{"IP cameras"}}`, `ext_mes_rest{{"MES (REST)"}}`; client infrastructure likewise: `Corporate proxy`, `Active Directory` |
| Network boundary | `subgraph net_<name>` | compose network name |
| Human actor | stadium `id(["Role"])` | role, not person |

**Arrows** are labelled with protocol and purpose (`-->|HTTPS 443: API|`).
Unlabelled arrows are not allowed in system-level diagrams.

**Ports and exposure.** Topology diagrams show host-exposed ports on the
boundary of the deployment subgraph. Internal-only ports are omitted unless a
request-flow diagram needs them.

**Required diagrams per reference deployment:**

1. `topology.mmd` — `flowchart` of services, networks, volumes, exposed ports.
2. `data-flows.mmd` — inputs/outputs map for every service and external
   integration in the deployment. See §7a.
3. `request-flows.mmd` — at least one `sequenceDiagram` covering the primary
   inter-service path (e.g., camera ingest → processing → storage → API →
   client). Intra-service steps are collapsed to one line with a link to the
   service repo's diagram.

**Required repo-level diagrams:**

- `system-context.mmd` — one box for Pacefactory, one for each external actor
  and client-owned system.
- `network/site-network.mmd` — what the client site must provide (proxy,
  DNS, AD/SSSD, Teleport path, egress allow-list) and where the deployment
  host sits.
- `reference/profile-dependencies.md` embeds a `flowchart` of profile
  requires/conflicts edges.

---

## 7a. Network and data flow inputs/outputs

Every reference deployment has a `data-flows.mmd` plus an accompanying table
in its README that enumerates **all** flows in and out of every service,
whether the other end is another Pacefactory service or a 3rd-party system.
The profile pages (§5) hold the same information scoped to one profile.

### Flow table

Columns, one row per directed flow:

`From | To | Direction | Protocol | Port / endpoint / topic / table | Payload | Trigger | Profile | Details`

- `From` / `To` use glossary node IDs for Pacefactory services and the
  integration-type ID (see below) for external systems.
- `Direction` is from the deployment's point of view: `in`, `out`, or `bidi`.
- `Protocol` is the wire protocol (`RTSP`, `HTTPS`, `SQL/TDS`, `MQTT`, `OPC UA`, `AMQP`, …). Use the glossary spelling.
- `Port / endpoint / topic / table` is whatever identifies the channel at
  this level: host port for network flows, topic prefix for message buses,
  table or schema name for direct database access, path for file exchange.
- `Payload` is a one-phrase description (`H.264 video`, `event JSON`,
  `work-order rows`). The full schema lives in the owning service repo's
  `docs/reference/schemas/` and is linked from `Details`.
- `Trigger` is `continuous`, `polling <interval>`, `on event`, or `on demand`.
- `Profile` is the profile that enables this flow.
- `Details` links to the service repo doc that covers the flow in depth.

### External integration types

External systems are grouped into **integration types**, each with a stable
ID in the glossary and a page under `docs/architecture/integrations/`. The
initial set — each is a placeholder to be filled in as the per-repo docs are
built:

| Integration type | Glossary ID | Typical protocol(s) | Direction | Page |
|---|---|---|---|---|
| IP cameras | `ext_cameras` | RTSP (video in), ONVIF/HTTP (control) | in | `integrations/cameras-rtsp.md` — TODO |
| MES via REST API | `ext_mes_rest` | HTTP/HTTPS REST | bidi | `integrations/mes-rest.md` — TODO |
| MES via direct SQL | `ext_mes_sql` | SQL over TDS / PostgreSQL wire / etc. | bidi | `integrations/mes-sql.md` — TODO |
| MQTT broker | `ext_mqtt` | MQTT / MQTTS | bidi | `integrations/mqtt.md` — TODO |
| OPC server | `ext_opc` | OPC UA (and/or OPC DA) | in (typ.) | `integrations/opc.md` — TODO |
| *(add as discovered)* | `ext_<name>` | | | |

Each integration page has the same skeleton, and only the skeleton is
prescribed here; content is filled in from the service repos that implement
the integration:

```markdown
---
title: <Integration type>
type: reference
derived_from:
  - <profile definitions that enable it>
  - <link to implementing service repo docs>
last_verified: YYYY-MM-DD
verified_against: <SHA>
---
## What it connects to           (the class of 3rd-party system, vendor-neutral)
## Which Pacefactory services participate, and via which profile(s)
## Direction and protocol(s)     (network-level: ports, TLS, auth mechanism by name only)
## Client-side network requirements  (firewall rules, DNS, credentials the site must provide — link to network/site-requirements.md)
## Payload summary               (one paragraph; link to schema docs in the owning service repo)
## Failure modes at the boundary (what happens when the external system is unreachable — summary + link)
## Variants                      (TODO: per-vendor or per-protocol specifics; document in service repos and link)
```

Rules:

- This repo records **that** a flow exists, its direction, protocol, and
  channel identifier. It does not document message formats, vendor quirks,
  authentication flows, or retry behaviour beyond a one-line summary and a
  link. Those belong to the service repo that implements the integration.
- A flow that appears in a service repo's docs but not in this repo's flow
  tables is a defect in this repo. A flow in this repo with no implementing
  code is a defect in this repo.
- Internal flows (service → service) are held to the same table. No flow is
  exempt because "it's just Docker networking".

### `data-flows.mmd`

- A `flowchart` with the deployment as a `subgraph`, services inside, external
  integration types outside as hexagons, and one labelled arrow per row of
  the flow table (`-->|RTSP 554: H.264 video|`). Many-to-one flows (e.g., many
  cameras) are drawn as one arrow with a multiplicity note in the label.
- Inbound flows enter from the left, outbound leave to the right where the
  layout allows, so direction is readable at a glance.
- Integration types not enabled by the reference deployment's profiles are
  omitted, not greyed out.

---

## 8. Cross-repo linking

- Links to service repos point at a **path**, not a line number, and prefer
  the default branch (`.../blob/main/docs/...`). Pinning to a SHA is allowed
  only when the doc is itself pinned to a release.
- Each reference to a service includes a link to that service's
  `docs/architecture/README.md`. Add the link the first time the service is
  mentioned on a page.
- Reverse links: each service repo's `README.md` links back to this folder's
  `README.md` with the sentence "See deployment-scripts for how this service is
  deployed alongside others." This standard cannot enforce that; the
  service-repo standard requires it.
- Never copy a service repo's tables or diagrams into this repo. Summarise in
  one sentence and link.

---

## 9. Glossary (`glossary.md`)

The authoritative vocabulary for all Pacefactory documentation. Service repos
defer to it. Minimum entries:

- **site**, **deployment**, **profile**, **service**, **reference deployment**,
  **build script** (`build.sh`), **integration type**, **flow**, and one entry
  per service with: display name, Mermaid node ID, owning repo, one-sentence
  purpose.
- One entry per external integration type (§7a) with: display name, `ext_*`
  node ID, protocol spelling to use in docs.
- Terms are defined once. Other docs link to the glossary anchor rather than
  redefining.

---

## 10. Change triggers

Update the corresponding docs **in the same PR** when any of these changes:

| Change | Update |
|---|---|
| Profile added, removed, renamed | `profiles/README.md`, its page + `.mmd`, `profile-dependencies.md`, glossary if a new service appears |
| Service added to / removed from a profile | that profile's page + `.mmd`; rebuild any reference deployment that includes the profile |
| Build script env var added/changed/removed | `environment-variables.md`; the affected profile page |
| Build script merge/override behaviour changes | rebuild **all** reference deployments and re-derive their diagrams |
| Exposed port, network, or volume changes | affected reference deployment `topology.mmd` |
| A service gains/loses an input or output, or its protocol/channel changes | flow table + `data-flows.mmd` in every reference deployment that includes it; the profile page; the integration page if external |
| A new class of 3rd-party system is integrated | glossary `ext_*` entry, new `integrations/<type>.md`, flow tables |
| Client network requirement changes | `network/site-requirements.md` and `site-network.mmd` |

Rebuilding is the check: re-run `build.sh` with each reference deployment's
recorded inputs, diff the committed output, and re-derive diagrams if the
diff is non-empty. This is designed to
be automatable later; for now it is a manual PR step.

---

## 11. AI assistant instructions (`CLAUDE.md` addition for this repo)

```markdown
## Architecture documentation
- Follow `docs/architecture/ARCHITECTURE_DOCS_STANDARD.md`. It extends the service-repo standard.
- System-level diagrams are derived from *built* compose output, never from fragments. To update one, run `build.sh` with the reference deployment's recorded `build.env` / `build.args` (exact command in its README), diff the result against `docker-compose.built.yml`, then update the diagrams from the new output.
- `build.sh` is universal. Never create per-deployment build scripts or wrappers; record inputs instead.
- Every service in a topology diagram must also appear in the flow table and `data-flows.mmd` with at least one input or output. If you cannot find any, write `TODO(source)` in the table rather than omitting the service.
- External systems use `ext_*` glossary IDs. If an integration type has no ID, add the glossary entry and a skeleton `integrations/<type>.md` first.
- Record flows at the network level (direction, protocol, channel). Link to the service repo for payload schemas and integration internals; do not copy them here.
- Use the Mermaid node IDs in `docs/architecture/glossary.md`. Do not invent IDs. If a service has no ID, add a glossary entry first.
- Every arrow in a system-level diagram is labelled with protocol and purpose.
- The profile catalog and env var reference are derived from profile definitions and `build.sh` respectively. When asked to update them, first list discrepancies between the doc and the source, then fix.
- Do not describe service internals here. Link to `<service repo>/docs/architecture/README.md`.
- Optional-profile services are drawn dashed and labelled with their profile.
```

---

## 12. Open questions for the first Claude Code session

Resolve these against the actual repo, then delete this section:

- [ ] What are the real profile names, and which are required? (Derive from `build.sh` and profile definitions; populate §5.)
- [ ] How does `build.sh` take its inputs — flags, env file, both? Adjust the `build.env` / `build.args` convention in §3 to match.
- [ ] Does `build.sh` emit a single compose file or several (e.g., override files)? If several, §4 commits all of them.
- [ ] Which external integration types actually exist in the current codebases, and which services implement each? Seed §7a's table and the glossary `ext_*` entries from that.
- [ ] Which 3–6 profile/env combinations deserve reference-deployment status?
- [ ] Where does the existing client network requirements doc live today, and should it move into `network/` or be linked?
- [ ] Is there a canonical service list already (e.g., in `build.sh` or the profile definitions) that should seed `glossary.md`?
- [ ] Does `build.sh` have a dry-run / print-only mode that makes rebuilding cheap in a docs check?
