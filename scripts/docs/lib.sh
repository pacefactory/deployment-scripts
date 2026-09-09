#!/bin/bash
# Shared helpers for the documentation generators in scripts/docs/.
# All generators must be run from the repository root.

DOCS_TOOLS_DIR="scripts/docs"
SERVICES_TSV="$DOCS_TOOLS_DIR/services.tsv"
EXTERNALS_TSV="$DOCS_TOOLS_DIR/externals.tsv"
FLOWS_TSV="$DOCS_TOOLS_DIR/flows.tsv"
REF_ROOT="docs/architecture/reference-deployments"
PROFILES_DIR="docs/architecture/profiles"
TODAY="$(date -u +%Y-%m-%d)"
GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Profile classification, mirrored from build.sh (see build.sh:30-34 and :51-58).
FORCED_PROFILES="base custom tools expresso-010"
DEFAULT_ON_PROFILES="social rdb node-red mqtt-public mqtts-public"

# node_id <compose service name> -> Mermaid node ID (hyphens are not safe in IDs)
node_id() { printf '%s' "$1" | tr '-' '_'; }
vol_id()  { printf 'vol_%s' "$(printf '%s' "$1" | tr '-' '_')"; }
net_id()  { printf 'net_%s' "$(printf '%s' "$1" | tr '-' '_')"; }

# Escape text for use inside a quoted Mermaid label
mlabel() { printf '%s' "$1" | sed 's/"/'"'"'/g; s/|/\//g'; }

# lookup_service <field-index> <service>  (fields: 1 service 2 node_id 3 display 4 image 5 owner_repo 6 owner_kind 7 purpose)
lookup_service() { awk -F'\t' -v s="$2" -v f="$1" '!/^#/ && $1==s {print $f; exit}' "$SERVICES_TSV"; }
# lookup_external <field-index> <node_id> (fields: 1 node_id 2 display 3 protocols 4 direction 5 page 6 description)
lookup_external() { awk -F'\t' -v s="$2" -v f="$1" '!/^#/ && $1==s {print $f; exit}' "$EXTERNALS_TSV"; }

# profile_of_service <service>: the fragment that defines the service's image (its home profile)
# profile_of_service <service> [candidate profiles...]: the fragment (among the
# candidates, default all) that defines the service's image, i.e. its home profile
profile_of_service() {
  local svc="$1"; shift
  local cands="$*" f p
  for f in compose/docker-compose.*.yml; do
    p="${f#compose/docker-compose.}"; p="${p%.yml}"
    [[ -n "$cands" && " $cands " != *" $p "* ]] && continue
    if [[ "$(yq ".services[\"$svc\"].image // \"\"" "$f")" != "" ]]; then echo "$p"; return; fi
  done
  echo "unknown"
}
# linkify_profiles "a, b" -> markdown links to profile pages; empty -> "none"
linkify_profiles() { if [[ -z "$1" ]]; then echo none; else echo "$1" | sed 's/\([a-z0-9-][a-z0-9-]*\)/[`\1`](\1.md)/g'; fi; }
trim() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]\{2,\}/ /g'; }

profile_class() {
  local p="$1" f="compose/docker-compose.$1.yml"
  if [[ " $FORCED_PROFILES " == *" $p "* ]]; then echo "forced (build.sh)"; return; fi
  local parent; parent="$(parent_of_profile "$p")"
  if [[ "$(yq '.["x-pf-info"].sub-profile // false' "$f")" == "true" ]]; then
    if [[ " $DEFAULT_ON_PROFILES " == *" $p "* ]]; then echo "sub-profile of $parent, default on"; else echo "sub-profile of $parent, default off"; fi
    return
  fi
  if [[ " $DEFAULT_ON_PROFILES " == *" $p "* ]]; then echo "prompted, default on"; return; fi
  local req; req="$(required_by_profiles "$p")"
  if [[ -n "$req" ]]; then echo "prompted, default off; forced by $req"; return; fi
  echo "prompted, default off"
}

parent_of_profile() {
  local p="$1" f q out=""
  for f in compose/docker-compose.*.yml; do
    q="${f#compose/docker-compose.}"; q="${q%.yml}"
    if yq -e '.["x-pf-info"].sub-profiles // [] | .[]' "$f" 2>/dev/null | grep -qx "$p"; then out="$out${out:+, }$q"; fi
  done
  echo "$out"
}

required_by_profiles() {
  local p="$1" f q out=""
  for f in compose/docker-compose.*.yml; do
    q="${f#compose/docker-compose.}"; q="${q%.yml}"
    if yq -e '.["x-pf-info"].required-profiles // [] | .[]' "$f" 2>/dev/null | grep -qx "$p"; then out="$out${out:+, }$q"; fi
  done
  echo "$out"
}

# enabled_profiles <deployment dir>: profiles that are "true" in the recorded .settings and exist as fragments
enabled_profiles() {
  ( . "$1/.settings" 2>/dev/null; for k in "${!SCV2_PROFILES[@]}"; do
      [[ "${SCV2_PROFILES[$k]}" == "true" && -f "compose/docker-compose.$k.yml" ]] && echo "$k"; done | sort )
}

# YAML doc header
doc_header() { # title type derived_from...
  local title="$1" type="$2"; shift 2
  printf -- '---\ntitle: %s\ntype: %s\nderived_from:\n' "$title" "$type"
  local d; for d in "$@"; do printf '  - %s\n' "$d"; done
  printf 'last_verified: %s\nverified_against: %s\n---\n' "$TODAY" "$GIT_SHA"
}
# Mermaid comment header (.mmd files cannot carry YAML front matter)
mmd_header() { # derived_from...
  local d; for d in "$@"; do printf '%%%% derived_from: %s\n' "$d"; done
  printf '%%%% last_verified: %s (%s)\n' "$TODAY" "$GIT_SHA"
}
