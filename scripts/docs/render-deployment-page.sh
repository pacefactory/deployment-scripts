#!/bin/bash
# render-deployment-page.sh <name> | --all
# For a reference deployment, derives topology.mmd, data-flows.mmd and
# request-flows.mmd and writes README.md from the committed build output, the
# recorded inputs and scripts/docs/deployments.tsv.
set -euo pipefail
source scripts/docs/lib.sh

render_one() {
  local name="$1" dir="$REF_ROOT/$1" built="$REF_ROOT/$1/docker-compose.built.yml"
  [[ -f "$built" ]] || { echo >&2 "missing $built; run scripts/docs/build-reference-deployment.sh $name first"; return 1; }
  local display purpose notable tmpl notes
  IFS=$'\t' read -r _ display purpose notable tmpl notes < <(awk -F'\t' -v n="$name" '!/^#/ && $1==n' "$DOCS_TOOLS_DIR/deployments.tsv")
  [[ -n "$display" ]] || { echo >&2 "$name not in deployments.tsv"; return 1; }

  ./scripts/docs/render-topology.sh "$name" > "$dir/topology.mmd"
  ./scripts/docs/render-flows.sh --deployment "$name" --mermaid > "$dir/data-flows.mmd"
  { mmd_header "$built" "scripts/docs/request-flows/$tmpl.mmd"; cat "scripts/docs/request-flows/$tmpl.mmd"; } > "$dir/request-flows.mmd"

  local enabled; enabled="$(enabled_profiles "$dir" | tr '\n' ' ')"
  {
    doc_header "Reference deployment: $display" reference "$built" "$dir/.env" "$dir/.settings" "$dir/build-command.txt" "scripts/docs/flows.tsv" "scripts/docs/deployments.tsv"
    echo
    echo "# Reference deployment: $display"
    echo
    echo "$purpose"
    echo
    [[ -n "$notes" ]] && { echo "$notes"; echo; }
    echo "## Reproduce"
    echo
    echo "From the repository root, with mikefarah \`yq\` v4 and the docker compose plugin installed (no daemon required):"
    echo
    echo '```bash'
    echo "./scripts/docs/build-reference-deployment.sh $name          # rewrite docker-compose.built.yml"
    echo "./scripts/docs/build-reference-deployment.sh $name --check  # exit 1 if the committed output is stale"
    echo '```'
    echo
    echo "The wrapper copies the recorded [\`.env\`](.env) and [\`.settings\`](.settings) into the repo root, runs \`./build.sh -q -n deployment-scripts\`, and normalises host paths to the canonical checkout \`/home/pacefactory/scv2/git_clones/deployment-scripts\`. The \`docker compose config\` command build.sh assembled on the last run is recorded in [\`build-command.txt\`](build-command.txt):"
    echo
    echo '```bash'; cat "$dir/build-command.txt" 2>/dev/null || echo "TODO(source): build-command.txt missing; rebuild"; echo '```'
    echo
    echo "## Recorded inputs"
    echo
    echo "Notable overrides: $notable."
    echo
    echo '`.env`:'; echo; echo '```bash'; cat "$dir/.env"; echo '```'; echo
    echo '`.settings`:'; echo; echo '```bash'; cat "$dir/.settings"; echo '```'; echo
    echo "## Profiles enabled"
    echo
    echo "| Profile | Class | Page |"; echo "|---|---|---|"
    for p in $enabled; do echo "| \`$p\` | $(profile_class "$p") | [$p](../../profiles/$p.md) |"; done
    echo
    echo "Profiles marked true in \`.settings\` but without a fragment in this checkout (for example \`custom\`) are ignored by \`build.sh\`."
    echo
    echo "## Services"
    echo
    echo "| Service | Node ID | Image (resolved) | Home profile | Networks | Host ports | Notes |"; echo "|---|---|---|---|---|---|---|"
    for s in $(yq '.services | keys | .[]' "$built"); do
      local img nets ports notes_s="" home
      img=$(yq ".services[\"$s\"].image" "$built"); home=$(profile_of_service "$s" $enabled)
      nets=$(yq ".services[\"$s\"].networks // {} | keys | .[]" "$built" | paste -sd, - | sed 's/,/, /g'); [[ -z "$nets" ]] && nets="$(yq ".services[\"$s\"].network_mode // \"default\"" "$built")"
      ports=""; local np; np=$(yq ".services[\"$s\"].ports // [] | length" "$built")
      for ((k=0;k<np;k++)); do
        local pp pt pi; pp=$(yq ".services[\"$s\"].ports[$k].published // \"ephemeral\"" "$built"); pt=$(yq ".services[\"$s\"].ports[$k].target" "$built"); pi=$(yq ".services[\"$s\"].ports[$k].host_ip // \"\"" "$built")
        ports="$ports${ports:+, }${pi:+$pi:}$pp->$pt"
      done
      [[ "$(yq ".services[\"$s\"].profiles // [] | length" "$built")" != "0" ]] && notes_s="on demand (compose profile)"
      [[ "$(yq ".services[\"$s\"].deploy.resources.reservations.devices // [] | length" "$built")" != "0" ]] && notes_s="${notes_s:+$notes_s; }GPU reservation"
      [[ "$(yq ".services[\"$s\"].restart // \"\"" "$built")" == "no" ]] && notes_s="${notes_s:+$notes_s; }restart: no"
      echo "| \`$s\` | \`$(node_id "$s")\` | \`$img\` | [\`$home\`](../../profiles/$home.md) | $nets | ${ports:-none} | $notes_s |"
    done
    echo
    echo "## Host-published ports"
    echo
    echo "| Host | Container | Protocol | Notes |"; echo "|---|---|---|---|"
    for s in $(yq '.services | keys | .[]' "$built"); do
      local n; n=$(yq ".services[\"$s\"].ports // [] | length" "$built")
      for ((i=0;i<n;i++)); do
        local pub tgt ip proto note=""
        pub=$(yq ".services[\"$s\"].ports[$i].published // \"\"" "$built"); tgt=$(yq ".services[\"$s\"].ports[$i].target" "$built"); ip=$(yq ".services[\"$s\"].ports[$i].host_ip // \"\"" "$built"); proto=$(yq ".services[\"$s\"].ports[$i].protocol // \"tcp\"" "$built")
        [[ -z "$pub" ]] && { pub="ephemeral"; note="host port assigned by Docker at start"; }
        [[ -n "$ip" ]] && { pub="$ip:$pub"; note="loopback only"; }
        echo "| $pub | \`$s:$tgt\` | $proto | $note |"
      done
    done
    echo
    echo "## Volumes"
    echo
    echo "| Volume | Mounted by |"; echo "|---|---|"
    for v in $(yq '.volumes // {} | keys | .[]' "$built"); do
      echo "| \`$v\` | $(yq ".services | to_entries | .[] | select((.value.volumes // []) | map(select(.source == \"$v\")) | length > 0) | .key" "$built" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g') |"
    done
    echo
    echo "## Inputs / Outputs (flow table)"
    echo
    echo "One row per directed flow (standard §7a). Node IDs are defined in the [glossary](../../glossary.md); external systems are catalogued under [integrations](../../integrations/README.md)."
    echo
    ./scripts/docs/render-flows.sh --deployment "$name" --table
    echo
    echo "## Diagrams"
    echo
    echo "### Topology"; echo; echo "Source: [\`topology.mmd\`](topology.mmd), derived from \`docker-compose.built.yml\`. Services grouped by their first compose network; dotted edges show additional network membership; parallelograms are host-published ports; cylinders are named volumes; dashed boxes are optional-profile services."; echo
    echo '```mermaid'; grep -v '^%%' "$dir/topology.mmd"; echo '```'; echo
    echo "### Data flows"; echo; echo "Source: [\`data-flows.mmd\`](data-flows.mmd). One arrow per row of the flow table; hexagons are external systems."; echo
    echo '```mermaid'; grep -v '^%%' "$dir/data-flows.mmd"; echo '```'; echo
    echo "### Request flows"; echo; echo "Source: [\`request-flows.mmd\`](request-flows.mmd) (template \`scripts/docs/request-flows/$tmpl.mmd\`). Intra-service steps are collapsed to one note; see the owning service repo for internals."; echo
    echo '```mermaid'; grep -v '^%%' "$dir/request-flows.mmd"; echo '```'
  } > "$dir/README.md"
  echo "wrote $dir/README.md"
}

render_catalog() {
  local out="$REF_ROOT/README.md"
  {
    doc_header "Reference deployments" reference "scripts/docs/deployments.tsv" "docs/architecture/reference-deployments/*/.settings" "docs/architecture/reference-deployments/*/.env"
    cat <<'MD'

# Reference deployments

Named, committed combinations of `.settings` and `.env` that represent real
classes of installation (architecture standard §4). Each directory holds the
recorded inputs, the normalised build output and diagrams derived from it. All
share the pins described in the standard: project name `deployment-scripts`,
canonical checkout `/home/pacefactory/scv2/git_clones/deployment-scripts`,
mongo sized for the 16 GB host tier. Rebuild with
`scripts/docs/build-reference-deployment.sh --all`; generated by
`scripts/docs/render-deployment-page.sh`.

| Name | Purpose | Profiles included | Notable env overrides | Diagrams |
|---|---|---|---|---|
MD
    while IFS=$'\t' read -r name display purpose notable tmpl notes; do
      [[ "$name" == \#* || -z "$name" ]] && continue
      profs=$(enabled_profiles "$REF_ROOT/$name" | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
      echo "| [$display]($name/README.md) | $purpose | $profs | $notable | [topology]($name/topology.mmd), [data flows]($name/data-flows.mmd), [request flows]($name/request-flows.mmd) |"
    done < "$DOCS_TOOLS_DIR/deployments.tsv"
  } > "$out"
  echo "wrote $out"
}

if [[ "${1:-}" == "--all" ]]; then for d in $(awk -F'\t' '!/^#/ {print $1}' "$DOCS_TOOLS_DIR/deployments.tsv"); do render_one "$d"; done; render_catalog; else render_one "$1"; fi
