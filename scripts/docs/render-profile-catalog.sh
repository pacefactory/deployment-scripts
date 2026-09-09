#!/bin/bash
# render-profile-catalog.sh: writes docs/architecture/profiles/README.md (the
# profile catalog, standard §5) and docs/reference/profile-dependencies.md.
set -euo pipefail
source scripts/docs/lib.sh
mkdir -p "$PROFILES_DIR" docs/reference

profiles=$(for f in compose/docker-compose.*.yml; do p="${f#compose/docker-compose.}"; echo "${p%.yml}"; done)

ext_for_profile() { awk -F'\t' -v p="$1" '!/^#/ && $8==p { if ($1 ~ /^ext_/) print $1; if ($2 ~ /^ext_/) print $2 }' "$FLOWS_TSV" | sort -u | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g'; }
owners_for_profile() {
  local f="compose/docker-compose.$1.yml" out=""
  for s in $(yq '.services | to_entries | .[] | select(.value.image != null) | .key' "$f"); do
    local r; r=$(lookup_service 5 "$s"); [[ "$(lookup_service 6 "$s")" == third-party ]] && continue
    out="$out${out:+<br>}[$(basename "$r")]($r)"
  done
  echo "${out:-third-party images only}"
}
conflicts_line() { grep -m1 '^| Conflicts with' "$PROFILES_DIR/$1.md" | cut -d'|' -f3 | trim; }

{
  doc_header "Profile catalog" reference "compose/docker-compose.*.yml" "build.sh" "scripts/docs/flows.tsv" "scripts/docs/services.tsv"
  cat <<'MD'

# Profile catalog

Every build profile `build.sh` knows about, derived from the fragments in
`compose/` and the classification constants in `build.sh`. A fragment missing
from this table is a docs defect; regenerate with
`scripts/docs/render-profile-catalog.sh`. Vocabulary: [glossary](../glossary.md).

`custom` is force-enabled by `build.sh` but has no fragment in the repository
(`compose/docker-compose.custom.yml` is gitignored). A site may add one; it is
merged in alphabetical position, after `base` and before `expresso-010`, so it
cannot override anything a later fragment sets.

| Profile | Class | Services added | Networks / volumes added | External integrations enabled | Parent | Requires | Required by | Conflicts with (inferred) | Owning service repo(s) | Page |
|---|---|---|---|---|---|---|---|---|---|---|
MD
  for p in $profiles; do
    f="compose/docker-compose.$p.yml"
    added=$(yq '.services | to_entries | .[] | select(.value.image != null) | .key' "$f" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
    modified=$(yq '.services | to_entries | .[] | select(.value.image == null) | .key' "$f" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
    nets=$(yq '.networks // {} | keys | .[]' "$f" | paste -sd, - | sed 's/,/, /g'); vols=$(yq '.volumes // {} | keys | .[]' "$f" | paste -sd, - | sed 's/,/, /g')
    nv="${nets:+networks: $nets}${nets:+${vols:+; }}${vols:+volumes: $vols}"
    reqs=$(yq '.["x-pf-info"].required-profiles // [] | .[]' "$f" | paste -sd, - | sed 's/,/, /g')
    echo "| \`$p\` | $(profile_class "$p") | ${added:-none}${modified:+ (modifies $modified)} | ${nv:-none} | $(ext_for_profile "$p" | sed 's/^$/none/') | $(linkify_profiles "$(parent_of_profile "$p")") | $(linkify_profiles "$reqs") | $(linkify_profiles "$(required_by_profiles "$p")") | $(conflicts_line "$p") | $(owners_for_profile "$p") | [$p.md]($p.md) |"
  done
  echo "| \`custom\` | forced (build.sh); fragment absent | site-defined | site-defined | site-defined | none | none | none | unknown | site | none |"
} > "$PROFILES_DIR/README.md"
echo "wrote $PROFILES_DIR/README.md"

{
  doc_header "Profile dependencies" reference "compose/docker-compose.*.yml" "build.sh"
  cat <<'MD'

# Profile dependencies

Edges are derived from `x-pf-info.sub-profiles`, `x-pf-info.required-profiles`
and the forced/default-on constants in `build.sh`. Conflicts are **inferred**
(same container name or same default host port in two fragments); `build.sh`
has no conflict check and will happily assemble a conflicting selection, which
then fails at `docker compose up` with a port or name clash.

Legend: solid arrow `parent --> sub-profile` = offered after the parent is
enabled; thick arrow `A ==> B` = A force-enables B; dotted line = inferred
conflict; double-bordered boxes are forced profiles; dashed boxes are default-off.

```mermaid
flowchart TD
  classDef forced stroke-width:3px
  classDef defaulton stroke-width:2px
  classDef defaultoff stroke-dasharray: 5 5
MD
  for p in $profiles; do echo "  $(node_id "$p")[\"$p\"]"; done
  for p in $profiles; do
    f="compose/docker-compose.$p.yml"
    for s in $(yq '.["x-pf-info"].sub-profiles // [] | .[]' "$f"); do echo "  $(node_id "$p") -->|\"sub-profile\"| $(node_id "$s")"; done
    for r in $(yq '.["x-pf-info"].required-profiles // [] | .[]' "$f"); do echo "  $(node_id "$p") ==>|\"requires\"| $(node_id "$r")"; done
  done
  # inferred conflicts (each pair once)
  declare -A done_pair=()
  for p in $profiles; do
    for q in $(grep -m1 '^| Conflicts with' "$PROFILES_DIR/$p.md" | grep -o '`[a-z0-9-]*`' | tr -d '`'); do
      key=$(printf '%s\n%s\n' "$p" "$q" | sort | paste -sd_ -); [[ -n "${done_pair[$key]:-}" ]] && continue; done_pair[$key]=1
      echo "  $(node_id "$p") -.-|\"conflict (inferred)\"| $(node_id "$q")"
    done
  done
  f_ids=""; on_ids=""; off_ids=""
  for p in $profiles; do
    c=$(profile_class "$p")
    if [[ "$c" == forced* ]]; then f_ids="$f_ids${f_ids:+,}$(node_id "$p")"; elif [[ "$c" == *"default on"* ]]; then on_ids="$on_ids${on_ids:+,}$(node_id "$p")"; else off_ids="$off_ids${off_ids:+,}$(node_id "$p")"; fi
  done
  echo "  class $f_ids forced"; echo "  class $on_ids defaulton"; echo "  class $off_ids defaultoff"
  echo '```'
  echo
  echo "## Table"
  echo
  echo "| Profile | Class | Parent | Sub-profiles | Requires | Required by | Conflicts with (inferred) |"
  echo "|---|---|---|---|---|---|---|"
  for p in $profiles; do
    f="compose/docker-compose.$p.yml"
    subs=$(yq '.["x-pf-info"].sub-profiles // [] | .[]' "$f" | paste -sd, - | sed 's/,/, /g')
    reqs=$(yq '.["x-pf-info"].required-profiles // [] | .[]' "$f" | paste -sd, - | sed 's/,/, /g')
    echo "| [\`$p\`](../architecture/profiles/$p.md) | $(profile_class "$p") | $(linkify_profiles "$(parent_of_profile "$p")" | sed 's#(\([a-z0-9-]*\).md)#(../architecture/profiles/\1.md)#g') | $(linkify_profiles "$subs" | sed 's#(\([a-z0-9-]*\).md)#(../architecture/profiles/\1.md)#g') | $(linkify_profiles "$reqs" | sed 's#(\([a-z0-9-]*\).md)#(../architecture/profiles/\1.md)#g') | $(linkify_profiles "$(required_by_profiles "$p")" | sed 's#(\([a-z0-9-]*\).md)#(../architecture/profiles/\1.md)#g') | $(conflicts_line "$p") |"
  done
} > docs/reference/profile-dependencies.md
echo "wrote docs/reference/profile-dependencies.md"
