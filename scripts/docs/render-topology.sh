#!/bin/bash
# render-topology.sh <reference-deployment-name>
# Emits a Mermaid flowchart of the deployment's services, compose networks,
# named volumes, bind mounts and host-published ports, derived ONLY from the
# committed docker-compose.built.yml of that deployment.
set -euo pipefail
source scripts/docs/lib.sh
name="$1"; dir="$REF_ROOT/$name"; built="$dir/docker-compose.built.yml"
[[ -f "$built" ]] || { echo >&2 "missing $built"; exit 1; }

mmd_header "$built" "scripts/docs/services.tsv"
echo "flowchart LR"
echo "  classDef optional stroke-dasharray: 5 5"
echo "  classDef ondemand stroke-width:1px,font-style:italic"
echo "  subgraph deployment[\"Reference deployment: $name (project $(yq '.name' "$built"))\"]"

services=$(yq '.services | keys | .[]' "$built")
enabled="$(enabled_profiles "$dir" | tr '\n' ' ')"
# Group services by their first compose network (config output sorts network keys).
declare -A placed=()
networks=$(yq '.networks // {} | keys | .[]' "$built")
for net in $networks "__default" "__none"; do
  members=""
  for svc in $services; do
    [[ -n "${placed[$svc]:-}" ]] && continue
    first=$(yq ".services[\"$svc\"].networks // {} | keys | .[0] // \"\"" "$built")
    mode=$(yq ".services[\"$svc\"].network_mode // \"\"" "$built")
    if [[ "$net" == "__none" && "$mode" == "none" ]] || [[ "$net" == "__default" && -z "$first" && "$mode" != "none" ]] || [[ "$first" == "$net" ]]; then
      members="$members $svc"; placed[$svc]=1
    fi
  done
  [[ -z "$members" ]] && continue
  case "$net" in
    __default) echo "    subgraph net_default[\"network: default\"]" ;;
    __none)    echo "    subgraph net_none[\"no network (network_mode: none)\"]" ;;
    *)         echo "    subgraph $(net_id "$net")[\"network: $net\"]" ;;
  esac
  for svc in $members; do
    id=$(node_id "$svc"); label="$svc"
    home=$(profile_of_service "$svc" $enabled)
    if [[ " $FORCED_PROFILES " != *" $home "* ]]; then label="$label (profile: $home)"; fi
    if [[ "$(yq ".services[\"$svc\"].deploy.resources.reservations.devices // [] | length" "$built")" != "0" ]]; then label="$label (GPU)"; fi
    if [[ "$(yq ".services[\"$svc\"].profiles // [] | length" "$built")" != "0" ]]; then label="$label (on demand)"; fi
    echo "      $id[\"$label\"]"
  done
  echo "    end"
done
echo "  end"

# Multi-homed services: dotted edge to each additional network subgraph
for svc in $services; do
  extra=$(yq ".services[\"$svc\"].networks // {} | keys | .[1:] | .[]" "$built")
  for net in $extra; do echo "  $(node_id "$svc") -.-|\"also joins\"| $(net_id "$net")"; done
done

# Host-published ports (parallelogram on the deployment boundary)
for svc in $services; do
  n=$(yq ".services[\"$svc\"].ports // [] | length" "$built")
  for ((i=0;i<n;i++)); do
    pub=$(yq ".services[\"$svc\"].ports[$i].published // \"\"" "$built")
    tgt=$(yq ".services[\"$svc\"].ports[$i].target" "$built")
    ip=$(yq ".services[\"$svc\"].ports[$i].host_ip // \"\"" "$built")
    proto=$(yq ".services[\"$svc\"].ports[$i].protocol // \"tcp\"" "$built")
    if [[ -z "$pub" ]]; then pid="port_eph_$(node_id "$svc")_$tgt"; plabel="host :ephemeral"; else pid="port_${ip//./_}${ip:+_}$pub"; plabel="host ${ip:+$ip}:$pub"; fi
    echo "  $pid[/\"$plabel\"/] -->|\"$proto -> $svc:$tgt\"| $(node_id "$svc")"
  done
done

# Volumes and bind mounts
declare -A vol_seen=()
for svc in $services; do
  n=$(yq ".services[\"$svc\"].volumes // [] | length" "$built")
  for ((i=0;i<n;i++)); do
    type=$(yq ".services[\"$svc\"].volumes[$i].type" "$built")
    src=$(yq ".services[\"$svc\"].volumes[$i].source // \"\"" "$built")
    tgt=$(yq ".services[\"$svc\"].volumes[$i].target" "$built")
    ro=$(yq ".services[\"$svc\"].volumes[$i].read_only // false" "$built"); rw="rw"; [[ "$ro" == "true" ]] && rw="ro"
    if [[ "$type" == "volume" ]]; then
      vid=$(vol_id "$src")
      [[ -z "${vol_seen[$vid]:-}" ]] && { echo "  $vid[(\"volume: $src\")]"; vol_seen[$vid]=1; }
      echo "  $(node_id "$svc") -->|\"$tgt ($rw)\"| $vid"
    elif [[ "$type" == "bind" ]]; then
      [[ -z "${vol_seen[ext_host_fs]:-}" ]] && { echo "  ext_host_fs{{\"Deployment host filesystem\"}}"; vol_seen[ext_host_fs]=1; }
      echo "  ext_host_fs -->|\"bind $src -> $tgt ($rw)\"| $(node_id "$svc")"
    fi
  done
done

# Optional-profile styling
opt=""
for svc in $services; do
  home=$(profile_of_service "$svc" $enabled)
  [[ " $FORCED_PROFILES " != *" $home "* ]] && opt="$opt${opt:+,}$(node_id "$svc")"
done
[[ -n "$opt" ]] && echo "  class $opt optional"
od=""
for svc in $services; do
  [[ "$(yq ".services[\"$svc\"].profiles // [] | length" "$built")" != "0" ]] && od="$od${od:+,}$(node_id "$svc")"
done
[[ -n "$od" ]] && echo "  class $od ondemand"
exit 0
