---
title: "Pacefactory Cross-Repo Architecture Documentation Standard"
type: standard
derived_from:
  - docs/architecture/
  - docs/reference/
  - scripts/docs/
  - build.sh
last_verified: 2026-09-09
verified_against: ccf3768
---

# Pacefactory Cross-Repo Architecture Documentation Standard

Version: 0.2-draft
Lives in: `deployment-scripts/docs/architecture/`
Extends: the service-repo [`DOCUMENTATION_STANDARD.md`](../DOCUMENTATION_STANDARD.md).
All rules there apply here unless this document says otherwise.

---

## 1. Purpose and scope

deployment-scripts owns the documentation of **how Pacefactory services are
composed into a deployment**. That includes:

- what build profiles exist, which are forced, default-on or default-off, and how they combine
- which services each profile contributes, and how those services are networked
- the **network and data flow inputs and outputs** of every service and every
  external integration: what each service receives, from where, over what
  protocol, and what it emits, to where (see §7a)
- every environment variable the build script accepts or a fragment interpolates, and what it changes
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
| How does the deployment talk to a 3rd-party system (cameras, client SQL database, MQTT clients, certificate authority)? | **This repo** (which service, which direction, which protocol); service repo (integration internals) |
| What does the client network need to look like? | **This repo** |

---

## 2. Source of truth

Because the compose file is *built* by `build.sh`, the source of truth is layered.
Every doc in this folder must name which layer it derives from:

1. **Profile definitions** (fragments `compose/docker-compose.<id>.yml`).
   Source for: profile catalog, per-profile service lists, profile dependencies,
   `x-pf-info` settings.
2. **Build script (`build.sh`) and the helpers it sources** (`scripts/common/*.sh`).
   Source for: forced and default-on profile sets, flag handling, the `.env` /
   `.settings` lifecycle, RAM-scaled mongo defaults.
3. **Built output**: the `docker-compose.yml` produced by `build.sh` for a
   specific `.settings` and `.env`.
   Source for: reference-deployment topology diagrams and service tables.
   Diagrams are drawn from the *output*, never hand-assembled from fragments, so
   that build script behaviour (merges, overrides, conditional services) is
   reflected.
4. **Service repo docs**: each service's `docs/reference/` and
   `docs/architecture/`.
   Source for: the *details* of a service's inputs and outputs (message
   formats, schemas, endpoint lists). This repo records that a flow exists,
   its direction and protocol; it links to the service repo for the rest.
5. **Data files in `scripts/docs/`** (`services.tsv`, `externals.tsv`,
   `flows.tsv`, `deployments.tsv`): the hand-maintained facts that cannot be
   read from compose alone (owning repo, external system classes, protocol and
   payload of each flow, with a `source` column citing the fragment line that
   evidences it). Every generated page lists the data files it read in
   `derived_from`.

Rule: if a doc's `derived_from` lists only fragments but describes a whole
deployment, it is wrong. Rebuild and re-derive from output.

Rule: the repo keeps the exact inputs `build.sh` reads for each reference
deployment (§4) so anyone, including an AI assistant, can reproduce the
output and re-derive the diagrams.

### Reproducible output

`docker compose config` bakes host-specific values into the output. Reference
deployments pin them so a rebuild on any machine is byte-identical:

| Source of variation | Pin |
|---|---|
| Checkout path, resolved into bind-mount sources (`../record_cli.py`, `../credentials/ssl`) | The wrapper rewrites the actual checkout path to the canonical production path `/home/pacefactory/scv2/git_clones/deployment-scripts` |
| `${HOME}` in `compose/docker-compose.tools.yml` | The wrapper rewrites `$HOME/scv2/videos` to `/home/pacefactory/scv2/videos` |
| Host RAM, read by `build.sh` to choose `MONGO_*_DEFAULT` | Every reference `.env` sets `MONGO_MEMORY_LIMIT` and `MONGO_WIREDTIGER_CACHE_GB` explicitly (the 16 GB host tier, `4g` / `1.5`) |
| Project name, defaulting to whatever project the local daemon lists first | The wrapper passes `-n deployment-scripts` |
| A site's `compose/docker-compose.custom.yml` | The wrapper refuses to run while one is present |
| `build-mac.sh` running inside a container (different `$HOME`) | Not supported for reference builds; it is a developer convenience, not a production path |

Default credentials that are committed in the fragments (the `pf_mosquitto`
`admin` password, the `ape_timescaledb` `postgres` password) appear in the
built output unchanged. They are not secrets in the sense of §7 of the
service-repo standard because they are already public in this repository;
the integration pages call them out so they can be rotated per site. Real
site values (`SERVER_NAME`, `LETSENCRYPT_EMAIL`, credentials files) never
appear in reference inputs; placeholders on `example.com` are used.

---

## 3. Directory layout

```
deployment-scripts/
  CLAUDE.md
  build.sh                               # universal; the only build script
  scripts/docs/                          # generators and their data files (not docs)
    build-reference-deployment.sh        # wrapper: recorded inputs -> normalised built output
    regenerate.sh                        # runs every generator; regenerate.sh --check is the drift test
    render-*.sh, check-docs.sh
    services.tsv, externals.tsv, flows.tsv, deployments.tsv, index.tsv
    request-flows/<template>.mmd         # hand-written sequence diagrams per deployment class
  docs/
    README.md                            # index (generated from index.tsv + the generated trees)
    DOCUMENTATION_STANDARD.md
    architecture/
      ARCHITECTURE_DOCS_STANDARD.md      # this file
      README.md                          # diagram table: file | shows | derived from | last verified
      glossary.md                        # authoritative vocabulary and node IDs (generated)
      system-context.mmd                 # Pacefactory as one system + external actors/systems
      profiles/
        README.md                        # profile catalog (generated, §5)
        <profile-id>.md                  # one per fragment (generated); embeds <profile-id>.mmd
        <profile-id>.mmd
      reference-deployments/
        README.md                        # table of named deployments (§4)
        <deployment-name>/
          .env                           # recorded input: variables build.sh reads and rewrites
          .settings                      # recorded input: profile selection and project name
          build-command.txt              # the docker compose ... config line build.sh assembled
          docker-compose.built.yml       # committed, normalised build.sh output; never hand-edited
          topology.mmd                   # derived from the built output
          data-flows.mmd                 # inputs/outputs map (§7a)
          request-flows.mmd              # inter-service sequence diagram(s)
          README.md                      # generated: purpose, reproduce, inputs, tables, embedded diagrams
      integrations/
        README.md                        # catalogue of external integration types (§7a)
        <integration-type>.md
      network/
        site-requirements.md             # client network requirements (carve-out; see §7b)
        site-network.mmd
    reference/
      build-script.md                    # flags, inputs, outputs and exit behaviour of build.sh / update.sh
      environment-variables.md           # every build.sh / fragment variable (generated, §6)
      profile-dependencies.md            # requires / sub-profile / inferred-conflict graph (generated)
      profile-metadata.md                # the x-pf-info schema
      ...                                # other code-derived references (mqtt listeners, ghosting, mongodb)
    how-to/
      build-a-deployment.md, update-a-deployment.md, add-a-profile.md,
      add-an-environment-variable.md, rebuild-reference-deployments.md, ...
```

`build.sh` reads two fixed files in the repository root, `.env` and
`.settings`, and rewrites both. It takes no path arguments for either. The
recorded inputs therefore use those exact names, and the wrapper copies them
into place for the duration of a build.

---

## 4. Reference deployments

A **reference deployment** is a named, committed combination of `.settings`
and `.env` that represents a real class of installation.

- The set is small (currently six, see
  [`reference-deployments/README.md`](reference-deployments/README.md)):
  default build, GPU variant, HTTPS via DigitalOcean, HTTPS via TLS cert
  file, full alerting, offline processing. Names describe the variant, not
  the client.
- Each has its recorded `.env` and `.settings`, the `build-command.txt`
  build.sh assembled on the last run, the committed normalised output
  `docker-compose.built.yml`, and diagrams derived from that output.
- `build.sh` itself is universal and lives once at the repo root. Reference
  deployments never carry a copy of it. A **thin wrapper** is permitted and
  lives once, at `scripts/docs/build-reference-deployment.sh`: it swaps the
  recorded inputs into place, runs `./build.sh -q -n deployment-scripts`,
  normalises the output as described in §2, and restores the operator's own
  files. It never changes what build.sh does.
- Diagrams for reference deployments are the **only** system-level topology
  diagrams. There is no hand-maintained "master" diagram of every possible
  service; it would be wrong by construction because profiles are optional.
- The built compose file is committed so that the diagram's
  `derived_from` points at a real file in the repo and drift is diffable.
  It carries a "BUILD OUTPUT - do not edit" comment at the top and is never
  edited by hand.
- `reference-deployments/README.md` columns:
  `Name | Purpose | Profiles included | Notable env overrides | Diagrams`.

---

## 5. Profile catalog

`profiles/README.md` is the authoritative list, generated by
`scripts/docs/render-profile-catalog.sh`. Columns:

`Profile | Class | Services added | Networks / volumes added | External integrations enabled | Parent | Requires | Required by | Conflicts with (inferred) | Owning service repo(s) | Page`

**Class** replaces a yes/no "Required?" column because `build.sh` has four
ways of deciding whether a profile is in a build. The values are:

| Class | Meaning | Source |
|---|---|---|
| `forced (build.sh)` | always enabled, never prompted | `build.sh:51-58` |
| `prompted, default on` | asked; yes unless `.settings` says otherwise | `build.sh:30-34, 42-48` |
| `prompted, default off` | asked; no unless `.settings` or a `--<id>` flag says otherwise | main loop |
| `prompted, default off; forced by <p>` | as above, but enabling `<p>` force-enables it | `x-pf-info.required-profiles` |
| `sub-profile of <p>, default on/off` | skipped in the main loop; asked only after `<p>` is enabled | `x-pf-info.sub-profile`, `sub-profiles` |

Rules:

- Every fragment in `compose/` appears in the catalog; a fragment in code but
  not in the catalog is a docs defect. `custom` is listed with a note that
  its fragment is site-supplied and absent from the repository.
- **Conflicts are inferred**, never read from code: `build.sh` has no conflict
  concept. Two profiles conflict when their fragments define a service with
  the same container name or publish the same default host port. The catalog
  labels the column "inferred" and each profile page states the reason.
- Each profile has its own page (generated) embedding a small `.mmd` showing
  only what that profile *adds*: its services, the services from other
  profiles they talk to (dashed, labelled with the contributing profile), and
  any external systems its services connect to (hexagons, see §7).
- Each profile page has an **Inputs / Outputs** table (same columns as §7a)
  listing every flow its services originate or terminate. Profiles that only
  change configuration state so explicitly.
- Profile pages link to each service's own repo for internals. They do not
  describe what the service does beyond one sentence (the `purpose` column of
  `services.tsv`).

---

## 6. Environment variable reference

`reference/environment-variables.md` documents every variable the **build
script** reads and every variable a **fragment interpolates**. It is generated
by `scripts/docs/render-env-reference.sh`. Columns:

`Variable | Kind | Default | Required | Profiles affected | Reaches service(s) as | Description | Defined in`

- **Kind** is `setting` (declared under `x-pf-info.settings`, prompted),
  `hidden setting` (declared with `hidden: true`, never prompted, written
  to `.env` when the profile is enabled), `interpolation only` (used by a
  fragment but not declared, so only settable by editing `.env` or the
  environment of the shell running `build.sh`), or `build.sh` (consumed by
  the script or its helpers).
- `Default` quotes the `x-pf-info` default exactly and, when the fragment has
  a different `${VAR:-x}` fallback, adds it as "compose fallback". `none` if
  there is no default anywhere.
- `Required` is `yes` when a fragment uses `${VAR:?}` and `yes (no fallback)`
  when a fragment uses bare `${VAR}`.
- `Profiles affected` lists every fragment that interpolates the variable;
  `all` for build.sh internals.
- `Reaches service(s) as` names the `service.key` or
  `service.environment=CONTAINER_VAR` the value lands in, so a reader can
  follow it into the service repo's own configuration reference.
- A variable whose only destinations are environment entries of the same name
  is a passthrough: its semantics are documented in the service repo, not here.
- Grouping: build.sh internals first, then one section per profile in
  fragment order. A variable declared in several fragments (`SERVER_NAME`,
  `HTTPS_PORT`, `MQTTS_CERT_SOURCE`) appears under each declaring profile
  with the full "Profiles affected" list; an interpolation-only variable
  appears once, under the first profile that uses it. Required variables come
  first within a group, then alphabetical.

---

## 7. Diagram rules (in addition to the service-repo standard)

**Stable IDs across the whole repo.** Every service has exactly one Mermaid
node ID, defined in `glossary.md` (generated from `services.tsv`) alongside
its display name and owning repo. The ID is the compose service name with
`-` replaced by `_`. All diagrams in this repo use that ID. Service repos are
encouraged to use the same ID for their "self" box.

**Visual conventions** (shape + label, never colour alone):

| Element | Mermaid shape | Label convention |
|---|---|---|
| Pacefactory service (forced profile) | rectangle `id["name"]` | compose service name |
| Service from an optional profile | rectangle with `classDef optional stroke-dasharray` | `name (profile: <home profile>)` |
| On-demand service (compose `profiles:`) | rectangle with `classDef ondemand` | `name (on demand)` |
| GPU-reserving service | rectangle | `name (GPU)` |
| Data store / named volume | cylinder `vol_<name>[("volume: name")]` | volume name |
| Bind mount | edge from `ext_host_fs` hexagon | `bind <host path> -> <container path> (rw/ro)` |
| External system / integration type | hexagon `ext_<type>{{"Display name"}}` | glossary display name |
| Compose network | `subgraph net_<name>["network: <name>"]` | compose network name |
| Multi-homed service | placed in its first network's subgraph; dotted edge `-.-|"also joins"| net_<other>` to each additional network | |
| Host-published port | parallelogram `port_<published>[/"host :<published>"/]` on the deployment boundary, edge labelled `<proto> -> <service>:<target>` | see below |
| Deployment boundary | `subgraph deployment[...]` | reference deployment name and project |
| Human actor | stadium `user_<role>(["Role"])` | role, not person |

**Ports and exposure.** Topology diagrams show every host-published port.
Three cases are distinguished by ID and label:

| Case | Compose form | ID | Label |
|---|---|---|---|
| Fixed host port | `"80:80"` | `port_80` | `host :80` |
| Ephemeral host port (Docker assigns it at start) | `"5380"` | `port_eph_<service>_<target>` | `host :ephemeral` |
| Loopback-only bind | `"127.0.0.1:3006:3005"` | `port_127_0_0_1_3006` | `host 127.0.0.1:3006` |

Internal-only container ports are omitted from topology diagrams; they appear
in the flow table's channel column.

**Arrows** are labelled with protocol and purpose (`-->|"HTTPS: web UI and API traffic"|`).
Unlabelled arrows are not allowed in system-level diagrams.

**Required diagrams per reference deployment:**

1. `topology.mmd`: `flowchart` of services, networks, volumes, exposed ports
   (generated by `render-topology.sh` from the built output).
2. `data-flows.mmd`: inputs/outputs map for every service and external
   integration in the deployment (generated by `render-flows.sh`). See §7a.
3. `request-flows.mmd`: at least one `sequenceDiagram` covering the primary
   inter-service path (camera ingest → processing → storage → API → client),
   plus the path that distinguishes the variant (certificate issuance, alert
   processing). Templates live in `scripts/docs/request-flows/`; intra-service
   steps are collapsed to one note with a link to the service repo's diagram.

**Required repo-level diagrams:**

- `system-context.mmd`: one box for Pacefactory, one for each external actor
  and client-owned system.
- `network/site-network.mmd`: what the client site must provide and where the
  deployment host sits (see §7b for the current carve-out).
- `reference/profile-dependencies.md` embeds a `flowchart` of sub-profile,
  requires and inferred-conflict edges.

All `.mmd` files and embedded Mermaid blocks must parse (`scripts/docs/check-docs.sh --mermaid`).

---

## 7a. Network and data flow inputs/outputs

Every reference deployment has a `data-flows.mmd` plus an accompanying table
in its README that enumerates **all** flows in and out of every service,
whether the other end is another Pacefactory service, a volume, or a
3rd-party system. The profile pages (§5) hold the same information scoped to
one profile. Both are projections of one data file, `scripts/docs/flows.tsv`;
edit the data file, then regenerate.

### Flow table

Columns, one row per directed flow:

`From | To | Direction | Protocol | Port / endpoint / topic / table | Payload | Trigger | Profile | Details`

- `From` / `To` use glossary node IDs: services, `vol_*` volumes, and
  `ext_*` integration types.
- `Direction` is from the deployment's point of view: `in`, `out`, or
  `bidi` for flows that cross the deployment boundary, and `internal` for
  service-to-service and service-to-volume flows.
- `Protocol` is the wire protocol using the glossary spelling (`RTSP`,
  `HTTP`, `HTTPS`, `WS`, `MQTT`, `MQTTS`, `MongoDB wire`, `Redis`,
  `PostgreSQL`, `SQL`, `SSH`, `file`).
- `Port / endpoint / topic / table` is whatever identifies the channel at
  this level: container host:port for internal flows, host port for published
  flows, topic prefix for message buses, table or database name for direct
  database access, path for file exchange.
- `Payload` is a one-phrase description. `TODO(source)` is acceptable when
  the fragment shows the connection but not what travels over it. The full
  schema lives in the owning service repo's `docs/reference/schemas/` and is
  linked from `Details`.
- `Trigger` is `continuous`, `polling <interval or schedule>`, `on event`,
  or `on demand`.
- `Profile` is the profile whose fragment evidences this flow.
- `Details` cites the fragment line(s) that evidence the flow (`source:`) and
  links to the service repo doc that covers the flow in depth.

A deployment's table contains the rows whose profile is enabled in its
`.settings` and whose service endpoints exist in its built output.

### External integration types

External systems are grouped into **integration types**, each with a stable
`ext_*` ID in `externals.tsv` (hence the glossary) and a page under
`docs/architecture/integrations/`. The current set was seeded from what the
fragments and scripts in this repository evidence; types that earlier drafts
of this standard anticipated but that no code here evidences (MES via REST,
OPC) are **not** listed until a fragment or service-repo doc shows them.

| Integration type | ID | Direction | Evidenced by |
|---|---|---|---|
| IP cameras | `ext_cameras` | in | `record_cli.py` RTSP handling; realtime's camera configuration volume |
| MQTT clients | `ext_mqtt_clients` | in | `mqtt-public`, `mqtts-public`, apigateway `/api/mqtt`. The deployment **is** the broker; third parties are clients of it. |
| Client SQL database | `ext_client_sql` | bidi | `rdb` fragment description |
| Let's Encrypt (ACME) | `ext_acme` | out | certbot services in the three certbot `https-*` fragments |
| DNS provider API | `ext_dns_api` | out | certbot DNS plugins and `credentials/*/credentials.ini` |
| Peer Pacefactory deployment | `ext_peer_deployment` | bidi | `PF_EXPRESSO_PUBLIC_URL_BASE`, `PF_REMOTE_TRAINER_URLS` |
| Container registry | `ext_registry` | out | `update.sh` pull, `runYq.sh`, offline-install tooling |
| GitHub | `ext_github` | out | `git pull` in fleet tooling, yq and compose binary downloads |
| Web browsers and API clients | `ext_web_clients` | in | every published HTTP(S) port |
| ntfy subscribers | `ext_ntfy_clients` | in | `ntfy` fragment |
| Node-RED flow endpoints | `ext_nodered_endpoints` | bidi | `node-red` fragment (endpoints are runtime configuration) |
| Corporate proxy | `ext_proxy` | out | `~/connect-to-proxy.sh` in `scripts/remote/update-server.sh` |
| Fleet operator workstation | `ext_fleet_operator` | in | `scripts/remote/` |
| Deployment host filesystem | `ext_host_fs` | bidi | every bind mount |

Each integration page has the same skeleton; only the skeleton is prescribed
here and content is filled in from the service repos that implement the
integration:

```markdown
---
title: "<Integration type>"
type: reference
derived_from:
  - <fragments that enable it>
  - scripts/docs/flows.tsv
last_verified: YYYY-MM-DD
verified_against: <SHA>
---
## What it connects to           (the class of 3rd-party system, vendor-neutral)
## Which Pacefactory services participate, and via which profile(s)
## Direction and protocol(s)     (network-level: ports, TLS, auth mechanism by name only)
## Client-side network requirements  (firewall rules, DNS, credentials the site must provide; link to network/site-requirements.md)
## Payload summary               (one paragraph; link to schema docs in the owning service repo)
## Failure modes at the boundary (what happens when the external system is unreachable; summary + link)
## Variants                      (TODO: per-vendor or per-protocol specifics; document in service repos and link)
```

Rules:

- This repo records **that** a flow exists, its direction, protocol, and
  channel identifier. It does not document message formats, vendor quirks,
  authentication flows, or retry behaviour beyond a one-line summary and a
  link. Those belong to the service repo that implements the integration.
- A flow that appears in a service repo's docs but not in `flows.tsv` is a
  defect in this repo. A flow in `flows.tsv` with no implementing code is a
  defect in this repo; the `source` column exists so this can be checked.
- Internal flows (service → service, service → volume) are held to the same
  table. No flow is exempt because "it's just Docker networking".

### `data-flows.mmd`

- A `flowchart` with the deployment as a `subgraph`, services and volumes
  inside, external integration types outside as hexagons, and one labelled
  arrow per row of the flow table (`-->|"RTSP: H.264/H.265 video"|`).
  Many-to-one flows (e.g., many cameras) are drawn as one arrow.
- Integration types not enabled by the reference deployment's profiles are
  omitted, not greyed out.

---

## 7b. Client network requirements (carve-out)

No client network requirements document exists in this repository yet. A
PowerPoint deck held by the technical lead covers some of it and must be
scrutinised against the per-repo sources of truth before its content is
adopted. Until then:

- `network/site-requirements.md` records only what this repository's own
  scripts and fragments evidence (published ports, egress targets, the
  proxy hook, the fleet SSH path, the host account and checkout path), each
  with its source line, and marks everything else `TODO(source)`.
- `network/site-network.mmd` draws only those evidenced elements.
- Active Directory, SSSD and Teleport are **not** drawn or described until a
  source in this or a service repo evidences them. The only AD-adjacent
  evidence today is `build.sh` unsetting `KRB5CCNAME`.

---

## 8. Cross-repo linking

- Links to service repos point at a **path**, not a line number, and prefer
  the default branch (`.../blob/main/docs/...`). Pinning to a SHA is allowed
  only when the doc is itself pinned to a release.
- Each reference to a service includes a link to that service's
  `docs/architecture/README.md`. Add the link the first time the service is
  mentioned on a page. Until a service repo adopts the standard, the link may
  resolve to nothing; the glossary says so.
- Reverse links: each service repo's `README.md` links back to this folder's
  `README.md` with the sentence "See deployment-scripts for how this service is
  deployed alongside others." This standard cannot enforce that; the
  service-repo standard requires it.
- Never copy a service repo's tables or diagrams into this repo. Summarise in
  one sentence and link.

---

## 9. Glossary (`glossary.md`)

The authoritative vocabulary for all Pacefactory documentation, generated by
`scripts/docs/render-glossary.sh` from a static term list plus
`services.tsv` and `externals.tsv`. Service repos defer to it. Minimum
entries:

- **site**, **deployment**, **build profile**, **compose profile**, **forced
  profile**, **default-on profile**, **sub-profile**, **required profile**,
  **setting**, **hidden setting**, **default_var**, **service**, **home
  profile**, **reference deployment**, **build script**, **integration type**,
  **flow**, and one entry per service with: display name, Mermaid node ID,
  image, home profile, owning repo and how that ownership was established,
  one-sentence purpose.
- One entry per external integration type (§7a) with: display name, `ext_*`
  node ID, protocol spelling to use in docs.
- Terms are defined once. Other docs link to the glossary anchor rather than
  redefining.
- The glossary is not vendored into service repos (unlike the documentation
  standard, service-repo standard §11). Each service repo records the few
  entries it needs (its own node ID, the terms it uses, the canonical glossary
  URL) in the "Repo-specific overrides" section of its `CLAUDE.md`.

---

## 10. Change triggers

Update the corresponding docs **in the same PR** when any of these changes.
"Regenerate" means run `scripts/docs/regenerate.sh` and commit the result.

| Change | Update |
|---|---|
| Profile added, removed, renamed | add/remove its row in `flows.tsv` if it has flows; regenerate (catalog, page, dependencies, glossary); rebuild any reference deployment that includes it |
| Service added to / removed from a profile | `services.tsv` row; `flows.tsv` rows; regenerate; rebuild affected reference deployments |
| Build script env var added/changed/removed | regenerate `environment-variables.md`; the affected profile page follows |
| Build script merge/override behaviour changes | rebuild **all** reference deployments and regenerate |
| Exposed port, network, or volume changes | rebuild affected reference deployments (topology follows) |
| A service gains/loses an input or output, or its protocol/channel changes | `flows.tsv`; regenerate; integration page if external |
| A new class of 3rd-party system is integrated | `externals.tsv` entry, new `integrations/<type>.md`, `flows.tsv` rows, `index.tsv` |
| Client network requirement changes | `network/site-requirements.md` and `site-network.mmd` |

Rebuilding is the check: `scripts/docs/regenerate.sh --check` rebuilds every
reference deployment against its committed output and exits non-zero on
drift; `git diff --exit-code docs` after `regenerate.sh` catches every other
generated file. This is designed to be automatable in CI; for now it is a
manual PR step (see [rebuild-reference-deployments](../how-to/rebuild-reference-deployments.md)).
