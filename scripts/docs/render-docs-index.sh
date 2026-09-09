#!/bin/bash
# render-docs-index.sh: writes docs/README.md (the only index of docs) from
# scripts/docs/index.tsv plus the generated profile and reference-deployment
# trees, and docs/architecture/README.md (the diagram table) from the .mmd headers.
set -euo pipefail
source scripts/docs/lib.sh

{
  doc_header "Documentation index" other "scripts/docs/index.tsv" "docs/"
  cat <<'MD'

# Documentation index

Every file under `docs/` is listed here (standard §2). Generated files say so
in their first paragraph; edit their generator or data file under
`scripts/docs/` and run `scripts/docs/regenerate.sh` instead of editing them.
Read the two standards first:

- [Documentation standard (service repos)](DOCUMENTATION_STANDARD.md)
- [Architecture documentation standard (this repo)](architecture/ARCHITECTURE_DOCS_STANDARD.md)

## Architecture

| Doc | Purpose |
|---|---|
MD
  awk -F'\t' '!/^#/ && $1 ~ /^docs\/architecture\// && $1 !~ /profiles\/|reference-deployments\// {printf "| [%s](%s) | %s |\n", substr($1,6), substr($1,6), $2}' "$DOCS_TOOLS_DIR/index.tsv"
  echo
  echo "### Profiles (generated)"
  echo
  echo "| Profile page | Diagram | Purpose |"; echo "|---|---|---|"
  for f in compose/docker-compose.*.yml; do p="${f#compose/docker-compose.}"; p="${p%.yml}"
    echo "| [architecture/profiles/$p.md](architecture/profiles/$p.md) | [$p.mmd](architecture/profiles/$p.mmd) | $(yq '.["x-pf-info"].name // ""' "$f" | trim) profile: services, settings and flows contributed by \`$p\` |"; done
  echo
  echo "### Reference deployments (generated)"
  echo
  echo "| Deployment | Files |"; echo "|---|---|"
  while IFS=$'\t' read -r name display purpose _; do
    [[ "$name" == \#* || -z "$name" ]] && continue
    d="architecture/reference-deployments/$name"
    echo "| [$display]($d/README.md) | [.env]($d/.env), [.settings]($d/.settings), [build-command.txt]($d/build-command.txt), [docker-compose.built.yml]($d/docker-compose.built.yml), [topology.mmd]($d/topology.mmd), [data-flows.mmd]($d/data-flows.mmd), [request-flows.mmd]($d/request-flows.mmd) |"
  done < "$DOCS_TOOLS_DIR/deployments.tsv"
  echo
  echo "## Reference"; echo; echo "| Doc | Purpose |"; echo "|---|---|"
  awk -F'\t' '!/^#/ && $1 ~ /^docs\/reference\// {printf "| [%s](%s) | %s |\n", substr($1,6), substr($1,6), $2}' "$DOCS_TOOLS_DIR/index.tsv"
  echo; echo "## How-to"; echo; echo "| Doc | Purpose |"; echo "|---|---|"
  awk -F'\t' '!/^#/ && $1 ~ /^docs\/how-to\// {printf "| [%s](%s) | %s |\n", substr($1,6), substr($1,6), $2}' "$DOCS_TOOLS_DIR/index.tsv"
  echo; echo "## Design notes and other"; echo; echo "| Doc | Purpose |"; echo "|---|---|"
  awk -F'\t' '!/^#/ && $1 ~ /^docs\/(design|upgrade)/ {printf "| [%s](%s) | %s |\n", substr($1,6), substr($1,6), $2}' "$DOCS_TOOLS_DIR/index.tsv"
  awk -F'\t' '!/^#/ && $1 ~ /^docs\/[A-Z_]+\.md$/ {printf "| [%s](%s) | %s |\n", substr($1,6), substr($1,6), $2}' "$DOCS_TOOLS_DIR/index.tsv"
  echo; echo "## Colocated READMEs outside docs/"; echo; echo "| File | Purpose |"; echo "|---|---|"
  awk -F'\t' '!/^#/ && $1 !~ /^docs\// {printf "| [%s](../%s) | %s |\n", $1, $1, $2}' "$DOCS_TOOLS_DIR/index.tsv"
  echo
  echo "## Tooling (not docs)"
  echo
  echo "Generators and data files live in \`scripts/docs/\`: \`regenerate.sh\`, \`build-reference-deployment.sh\`, \`render-*.sh\`, \`check-docs.sh\`, and the data files \`services.tsv\`, \`externals.tsv\`, \`flows.tsv\`, \`deployments.tsv\`, \`index.tsv\`, \`request-flows/*.mmd\`."
} > docs/README.md
echo "wrote docs/README.md"

{
  doc_header "Architecture documentation" other "docs/architecture/**/*.mmd" "docs/reference/profile-dependencies.md"
  cat <<'MD'

# Architecture documentation

How Pacefactory services are composed into a deployment. Governed by the
[architecture documentation standard](ARCHITECTURE_DOCS_STANDARD.md). Start with
the [glossary](glossary.md), then the [profile catalog](profiles/README.md), then
the [reference deployments](reference-deployments/README.md).

- [System context](system-context.mmd) and [integrations](integrations/README.md): what is outside the deployment.
- [Profiles](profiles/README.md): what each fragment adds.
- [Reference deployments](reference-deployments/README.md): six built variants with topology, data-flow and request-flow diagrams.
- [Network](network/site-requirements.md): what a client site must provide (carve-out).

## Diagrams

Every Mermaid source in this repository. All are validated with mermaid-cli by
`scripts/docs/check-docs.sh --mermaid`.

| Diagram file | What it shows | Derived from | Last verified |
|---|---|---|---|
MD
  for f in $(find docs -name '*.mmd' | sort); do
    rel="${f#docs/architecture/}"; [[ "$f" == docs/architecture/* ]] || rel="../${f#docs/}"
    derived=$(grep '^%% derived_from:' "$f" | sed 's/^%% derived_from: //' | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
    lv=$(grep -m1 '^%% last_verified:' "$f" | sed 's/^%% last_verified: //')
    case "$f" in
      */system-context.mmd) shows="Pacefactory deployment as one system with external actors and systems" ;;
      */site-network.mmd) shows="Client site network elements evidenced by this repo" ;;
      */profiles/*) shows="Services and flows contributed by profile \`$(basename "$f" .mmd)\`" ;;
      */topology.mmd) shows="Topology of reference deployment \`$(basename "$(dirname "$f")")\`: services, networks, volumes, published ports" ;;
      */data-flows.mmd) shows="Data flows of reference deployment \`$(basename "$(dirname "$f")")\`" ;;
      */request-flows.mmd) shows="Primary request sequences of reference deployment \`$(basename "$(dirname "$f")")\`" ;;
      *) shows="" ;;
    esac
    echo "| [$rel]($rel) | $shows | $derived | $lv |"
  done
  echo "| [../reference/profile-dependencies.md](../reference/profile-dependencies.md) (embedded) | Sub-profile, requires and inferred-conflict edges between build profiles | \`compose/docker-compose.*.yml\`, \`build.sh\` | see file header |"
} > docs/architecture/README.md
echo "wrote docs/architecture/README.md"
