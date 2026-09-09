#!/bin/bash
# render-flows.sh (--deployment <name> | --profile <profile>) (--table | --mermaid)
#
# Filters scripts/docs/flows.tsv and emits either the Markdown flow table
# (standard §7a columns) or the data-flows Mermaid flowchart.
#   --deployment: rows whose profile is enabled in the deployment's recorded
#                 .settings AND whose service endpoints exist in its
#                 docker-compose.built.yml (external and volume endpoints always pass)
#   --profile:    rows contributed by that profile only
set -euo pipefail
source scripts/docs/lib.sh

mode=""; sel=""; out=""
while [[ $# -gt 0 ]]; do case "$1" in
  --deployment) mode=deployment; sel="$2"; shift 2 ;;
  --profile) mode=profile; sel="$2"; shift 2 ;;
  --table|--mermaid) out="${1#--}"; shift ;;
  *) echo >&2 "unknown arg $1"; exit 2 ;;
esac; done
[[ -n "$mode" && -n "$out" ]] || { sed -n '2,12p' "$0"; exit 2; }

declare -A svc_present=()
if [[ "$mode" == deployment ]]; then
  dir="$REF_ROOT/$sel"; built="$dir/docker-compose.built.yml"
  profiles=" $(enabled_profiles "$dir" | tr '\n' ' ') "
  for s in $(yq '.services | keys | .[]' "$built"); do svc_present[$(node_id "$s")]=1; done
  derived=("$built" "$dir/.settings" "scripts/docs/flows.tsv")
else
  profiles=" $sel "
  # every service any fragment defines is a possible endpoint on a profile page
  for f in compose/docker-compose.*.yml; do for s in $(yq '.services | keys | .[]' "$f"); do svc_present[$(node_id "$s")]=1; done; done
  derived=("compose/docker-compose.$sel.yml" "scripts/docs/flows.tsv")
fi

endpoint_ok() { [[ "$1" == ext_* || "$1" == vol_* || -n "${svc_present[$1]:-}" ]]; }

# Select rows into an array of TSV lines
rows=()
while IFS=$'\t' read -r from to dir proto chan payload trig prof src details; do
  [[ "$from" == \#* || -z "$from" ]] && continue
  [[ "$profiles" == *" $prof "* ]] || continue
  endpoint_ok "$from" && endpoint_ok "$to" || continue
  rows+=("$from"$'\t'"$to"$'\t'"$dir"$'\t'"$proto"$'\t'"$chan"$'\t'"$payload"$'\t'"$trig"$'\t'"$prof"$'\t'"$src"$'\t'"$details")
done < "$FLOWS_TSV"

if [[ "$out" == table ]]; then
  echo "| From | To | Direction | Protocol | Port / endpoint / topic / table | Payload | Trigger | Profile | Details |"
  echo "|---|---|---|---|---|---|---|---|---|"
  for r in "${rows[@]}"; do
    IFS=$'\t' read -r from to dir proto chan payload trig prof src details <<<"$r"
    link="$details"; [[ "$details" == http* ]] && link="[link]($details)"
    echo "| \`$from\` | \`$to\` | $dir | $proto | $chan | $payload | $trig | $prof | source: \`$src\`; $link |"
  done
  exit 0
fi

# Mermaid data-flows diagram
mmd_header "${derived[@]}" "scripts/docs/services.tsv" "scripts/docs/externals.tsv"
echo "flowchart LR"
echo "  classDef optional stroke-dasharray: 5 5"
declare -A seen=()
inside=""; outside=""
for r in "${rows[@]}"; do
  IFS=$'\t' read -r from to dir proto chan payload trig prof src details <<<"$r"
  for n in "$from" "$to"; do
    [[ -n "${seen[$n]:-}" ]] && continue; seen[$n]=1
    if [[ "$n" == ext_* ]]; then
      outside+="  $n{{\"$(mlabel "$(lookup_external 2 "$n")")\"}}"$'\n'
    elif [[ "$n" == vol_* ]]; then
      inside+="    $n[(\"volume: ${n#vol_}\")]"$'\n'
    else
      svc=$(awk -F'\t' -v id="$n" '!/^#/ && $2==id {print $1; exit}' "$SERVICES_TSV")
      home=$(profile_of_service "$svc"); label="$svc"
      [[ " $FORCED_PROFILES " != *" $home "* ]] && label="$svc (profile: $home)"
      inside+="    $n[\"$label\"]"$'\n'
    fi
  done
done
title="$sel"; [[ "$mode" == profile ]] && title="services touched by profile $sel"
echo "  subgraph deployment[\"$title\"]"; printf '%s' "$inside"; echo "  end"
printf '%s' "$outside"
for r in "${rows[@]}"; do
  IFS=$'\t' read -r from to dir proto chan payload trig prof src details <<<"$r"
  label="$(mlabel "$proto: $payload")"
  case "$dir" in bidi) arrow="<-->" ;; *) arrow="-->" ;; esac
  echo "  $from $arrow|\"$label\"| $to"
done
opt=""
for n in "${!seen[@]}"; do
  [[ "$n" == ext_* || "$n" == vol_* ]] && continue
  svc=$(awk -F'\t' -v id="$n" '!/^#/ && $2==id {print $1; exit}' "$SERVICES_TSV")
  home=$(profile_of_service "$svc")
  [[ " $FORCED_PROFILES " != *" $home "* ]] && opt="$opt${opt:+,}$n"
done
[[ -n "$opt" ]] && echo "  class $opt optional"
exit 0
