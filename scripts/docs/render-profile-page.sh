#!/bin/bash
# render-profile-page.sh <profile-id> | --all
# Writes docs/architecture/profiles/<id>.md and <id>.mmd, derived from the
# profile's compose fragment, build.sh's classification constants (lib.sh),
# scripts/docs/flows.tsv and scripts/docs/services.tsv.
set -euo pipefail
source scripts/docs/lib.sh
mkdir -p "$PROFILES_DIR"

all_profiles() { for f in compose/docker-compose.*.yml; do p="${f#compose/docker-compose.}"; echo "${p%.yml}"; done; }

# Conflicts are inferred: two profiles that both define a service with the same
# container name, or publish the same default host port, cannot be enabled together.
container_names() { yq '.services | to_entries | .[] | select(.value.image != null) | .value.container_name // .key' "compose/docker-compose.$1.yml" | sed 's/\${PROJECT_PREFIX:-}//'; }
host_ports() { yq '.services[] | .ports // [] | .[]' "compose/docker-compose.$1.yml" 2>/dev/null | sed -E 's/^"?\$\{[A-Z_]+:-([0-9]+)\}:.*/\1/; s/^"?([0-9.]+:)?([0-9]+):.*/\2/' | grep -E '^[0-9]+$' | sort -u; }
inferred_conflicts() {
  local p="$1" q out=""
  local pn; pn="$(container_names "$p" | sort -u)"; local pp; pp="$(host_ports "$p")"
  for q in $(all_profiles); do
    [[ "$q" == "$p" ]] && continue
    local reason=""
    if [[ -n "$pn" ]] && comm -12 <(echo "$pn") <(container_names "$q" | sort -u) | grep -q .; then reason="same container name $(comm -12 <(echo "$pn") <(container_names "$q" | sort -u) | paste -sd, -)"; fi
    if [[ -n "$pp" ]] && comm -12 <(echo "$pp") <(host_ports "$q") | grep -q .; then reason="${reason:+$reason; }same host port $(comm -12 <(echo "$pp") <(host_ports "$q") | paste -sd, -)"; fi
    [[ -n "$reason" ]] && out="$out${out:+<br>}\`$q\` ($reason)"
  done
  echo "${out:-none found}"
}

render_one() {
  local p="$1" f="compose/docker-compose.$1.yml"
  local md="$PROFILES_DIR/$p.md" mmd="$PROFILES_DIR/$p.mmd"
  local name desc prompt
  name=$(yq '.["x-pf-info"].name // ""' "$f"); name="${name:-$p}"
  desc=$(yq '.["x-pf-info"].description // ""' "$f" | tr '\n' ' ' | trim)
  prompt=$(yq '.["x-pf-info"].prompt // ""' "$f")
  local subs reqs parent reqby cls
  subs=$(yq '.["x-pf-info"].sub-profiles // [] | .[]' "$f" | sed 's/.*/[`&`](&.md)/' | paste -sd, - | sed 's/,/, /g')
  reqs=$(yq '.["x-pf-info"].required-profiles // [] | .[]' "$f" | sed 's/.*/[`&`](&.md)/' | paste -sd, - | sed 's/,/, /g')
  parent=$(linkify_profiles "$(parent_of_profile "$p")")
  reqby=$(linkify_profiles "$(required_by_profiles "$p")")
  cls=$(profile_class "$p")

  ./scripts/docs/render-flows.sh --profile "$p" --mermaid > "$mmd"

  {
    doc_header "Profile: $p" reference "$f" "build.sh" "scripts/docs/flows.tsv" "scripts/docs/services.tsv"
    echo
    echo "# Profile: \`$p\`"
    echo
    echo "**Display name:** $name"
    echo
    if [[ -n "$desc" ]]; then echo "$desc"; else echo "TODO(source): no \`x-pf-info.description\` in the fragment."; fi
    echo
    echo "| Attribute | Value |"
    echo "|---|---|"
    echo "| Fragment | \`$f\` |"
    echo "| Class | $cls |"
    echo "| Prompt | ${prompt:-(default: \"Enable $name?\")} |"
    echo "| Parent profile(s) | $parent |"
    echo "| Sub-profiles | ${subs:-none} |"
    echo "| Requires (\`required-profiles\`) | ${reqs:-none} |"
    echo "| Required by | $reqby |"
    echo "| Conflicts with (inferred) | $(inferred_conflicts "$p") |"
    echo
    echo "## Services added"
    echo
    local added; added=$(yq '.services | to_entries | .[] | select(.value.image != null) | .key' "$f")
    if [[ -z "$added" ]]; then echo "None. This profile only modifies services from other profiles."; else
      echo "| Service | Node ID | Image | Owning repo | Purpose |"; echo "|---|---|---|---|---|"
      for s in $added; do
        local img own kind purpose
        img=$(yq ".services[\"$s\"].image" "$f"); own=$(lookup_service 5 "$s"); kind=$(lookup_service 6 "$s"); purpose=$(lookup_service 7 "$s")
        echo "| \`$s\` | \`$(node_id "$s")\` | \`$img\` | [$(basename "$own")]($own) ($kind) | $purpose |"
      done
    fi
    echo
    echo "## Services modified from other profiles"
    echo
    local modified; modified=$(yq '.services | to_entries | .[] | select(.value.image == null) | .key' "$f")
    if [[ -z "$modified" ]]; then echo "None."; else
      echo "| Service | Home profile | Keys this profile adds or overrides |"; echo "|---|---|---|"
      for s in $modified; do
        echo "| \`$s\` | [\`$(profile_of_service "$s")\`]($(profile_of_service "$s").md) | $(yq ".services[\"$s\"] | keys | .[]" "$f" | paste -sd, - | sed 's/,/, /g') |"
      done
    fi
    echo
    echo "## Networks and volumes added"
    echo
    local nets vols; nets=$(yq '.networks // {} | keys | .[]' "$f" | paste -sd, - | sed 's/,/, /g'); vols=$(yq '.volumes // {} | keys | .[]' "$f" | paste -sd, - | sed 's/,/, /g')
    echo "- Networks: ${nets:-none}"
    echo "- Named volumes: ${vols:-none}"
    echo
    echo "## Settings (\`x-pf-info.settings\`)"
    echo
    local settings; settings=$(yq '.["x-pf-info"].settings // {} | keys | .[]' "$f")
    if [[ -z "$settings" ]]; then echo "None."; else
      echo "| Variable | Default (as written) | Hidden | default_var | Description |"; echo "|---|---|---|---|---|"
      for v in $settings; do
        local def hid dv dsc
        def=$(yq ".[\"x-pf-info\"].settings[\"$v\"].default" "$f"); hid=$(yq ".[\"x-pf-info\"].settings[\"$v\"].hidden // false" "$f")
        dv=$(yq ".[\"x-pf-info\"].settings[\"$v\"].default_var // \"\"" "$f"); dsc=$(yq ".[\"x-pf-info\"].settings[\"$v\"].description // \"\"" "$f" | tr '\n' ' ' | trim)
        [[ -z "$def" ]] && def='""'
        echo "| \`$v\` | \`$def\` | $hid | ${dv:+\`$dv\`} | ${dsc:-(none in fragment)} |"
      done
      echo
      echo "See the [environment variable reference](../../reference/environment-variables.md) for where each value reaches."
    fi
    echo
    echo "## Inputs / Outputs"
    echo
    echo "Flows this profile originates or terminates. Node IDs are defined in the [glossary](../glossary.md)."
    echo
    local table; table=$(./scripts/docs/render-flows.sh --profile "$p" --table)
    if [[ $(echo "$table" | wc -l) -le 2 ]]; then echo "None. This profile changes configuration only; it adds no flow of its own."; else echo "$table"; fi
    echo
    echo "## Diagram"
    echo
    echo "Source: [\`$p.mmd\`]($p.mmd). Dashed boxes are services from optional profiles; hexagons are external systems."
    echo
    echo '```mermaid'
    grep -v '^%%' "$mmd"
    echo '```'
  } > "$md"
  echo "wrote $md"
}

if [[ "${1:-}" == "--all" ]]; then for p in $(all_profiles); do render_one "$p"; done; else render_one "$1"; fi
