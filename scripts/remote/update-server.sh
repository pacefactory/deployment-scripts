#!/usr/bin/env bash
# shellcheck disable=SC2329,SC1090,SC1091,SC2034
# (step functions are invoked indirectly by run_step; the proxy script,
# .settings and projectName.sh are sourced from the server's tree; QUIET_MODE
# is read by the sourced projectName.sh)
#
# update-server.sh - per-server update payload for the fleet update tooling.
#
# Normally streamed over ssh stdin by update-fleet.ps1:
#
#   ssh <user>@<host> bash -s -- [--check] [--health-delay N] < update-server.sh
#
# It can also be run directly on a server for debugging:
#
#   bash update-server.sh [--check] [--health-delay N]
#
# Everything is wrapped in functions so bash reads the whole script before
# executing anything, and main runs with stdin redirected from /dev/null so
# no remote command can consume the rest of the streamed script.
#
# Machine-readable markers (all other output is normal passthrough):
#
#   PF|BEGIN|v2|<hostname>|<epoch>
#   PF|INFO|<key>|<value>               keys: mode migrated branch release_before
#                                             release_after update_available
#                                             nonstandard_tags project_name
#                                             containers_up containers_total
#   PF|STEP|<step>|<rc>|<duration_sec>   steps: proxy repo fetch build tag_scan
#                                               update health
#   PF|TAG|<image_ref>                   pacefactory image not on latest/latest-gpu
#   PF|HEALTH|<container>|<status>       one per container that is not Up/healthy
#   PF|END|<exit_code>
#
# Marker protocol v2 (release image distribution): the tree is updated by the
# in-tree updater scripts/release/fetch-release.sh instead of `git pull`, and
# versions are read from .pf-release/VERSION as "<TAG> (<commit7>)". `migrated`
# is true when the updater exists in the tree; `branch` is only emitted while a
# .git directory is still present. v1 (git_pull/git_fetch steps, commit_before/
# commit_after) is still understood by update-fleet.ps1 for old payloads.
#
# Exit codes:
#   0   success (warnings, if any, are carried by the markers)
#   11  repo directory missing
#   12  release fetch failed (pull, extract or sync; conversion refused)
#   13  build.sh failed or produced an invalid docker-compose.yml
#   14  update.sh failed (or never reported "Deployment complete")
#   15  health check found no containers (deployment absent or docker down)
#   16  health check found degraded containers
#   17  server not migrated: no scripts/release/fetch-release.sh in the tree
#       (still a plain git checkout; run the install one-liner on it)
#
# The fetch step's own rc in check mode: 0 up to date, 3 update available,
# 4 conversion blocked by modified tracked files, 17 not migrated, anything
# else is a pull/login error. A step rc of 124 means the step was killed by
# its timeout.

REPO_DIR="${PF_INSTALL_DIR:-$HOME/scv2/git_clones/deployment-scripts}"
PROXY_SCRIPT="$HOME/connect-to-proxy.sh"
FETCH_SCRIPT="scripts/release/fetch-release.sh"
VERSION_FILE=".pf-release/VERSION"
INSTALL_ONE_LINER="curl -fsSL https://get.pacefactory.dev/install.sh | bash"
HEALTH_DELAY=15
CHECK_MODE=false
LAST_RC=0

# ---- marker helpers --------------------------------------------------------

# Emit one marker line. The leading newline guarantees the marker starts at
# column 0 even if a previous command left a partial line on stdout.
pf_marker() {
  local IFS='|'
  printf '\nPF|%s\n' "$*"
}

# Sanitize free text destined for a marker field: no CRs, no pipes.
pf_clean() {
  tr -d '\r' | tr '|' '/'
}

# Run a step function, record its rc in LAST_RC and emit the STEP marker.
#   run_step <marker_name> <function> [args...]
run_step() {
  local name="$1"
  shift
  local start=$SECONDS
  "$@"
  LAST_RC=$?
  pf_marker STEP "$name" "$LAST_RC" "$((SECONDS - start))"
  return "$LAST_RC"
}

# ---- steps -----------------------------------------------------------------

step_proxy() {
  if [[ ! -f "$PROXY_SCRIPT" ]]; then
    echo "proxy: $PROXY_SCRIPT not found, continuing without it"
    return 3
  fi
  # Sourced (not executed) so the proxy environment variables persist for the
  # git/docker steps below.
  source "$PROXY_SCRIPT"
}

step_repo() {
  cd "$REPO_DIR" || { echo "repo: cannot cd to $REPO_DIR"; return 1; }
}

# "<TAG> (<commit7>)" from .pf-release/VERSION, or "none" before migration.
release_version() {
  local tag commit
  if [[ ! -f "$VERSION_FILE" ]]; then
    printf 'none'
    return
  fi
  tag="$(sed -n 's/^TAG=//p' "$VERSION_FILE" | head -1)"
  commit="$(sed -n 's/^COMMIT=//p' "$VERSION_FILE" | head -1)"
  printf '%s (%s)' "${tag:-?}" "${commit:0:7}" | pf_clean
}

# migrated / branch markers; run after step_repo in both modes.
emit_tree_info() {
  if [[ -f "$FETCH_SCRIPT" ]]; then
    pf_marker INFO migrated true
  else
    pf_marker INFO migrated false
  fi
  if [[ -d .git ]]; then
    pf_marker INFO branch "$(git rev-parse --abbrev-ref HEAD 2>/dev/null | pf_clean)"
  fi
  pf_marker INFO release_before "$(release_version)"
}

not_migrated_message() {
  echo "fetch: $FETCH_SCRIPT not found in $REPO_DIR: this server has not been migrated to the release image."
  echo "fetch: run this on the server, then re-run the fleet update:"
  echo "fetch:   $INSTALL_ONE_LINER"
}

# Update mode: fetch the release with the in-tree updater (replaces git pull).
step_fetch() {
  if [[ ! -f "$FETCH_SCRIPT" ]]; then
    not_migrated_message
    pf_marker INFO release_after "$(release_version)"
    return 17
  fi
  timeout 600 bash "$FETCH_SCRIPT"
  local rc=$?
  pf_marker INFO release_after "$(release_version)"
  return "$rc"
}

# Check mode: read-only comparison against the published release.
step_fetch_check() {
  if [[ ! -f "$FETCH_SCRIPT" ]]; then
    not_migrated_message
    pf_marker INFO update_available unknown
    return 17
  fi
  timeout 300 bash "$FETCH_SCRIPT" --check
  local rc=$?
  case "$rc" in
    0) pf_marker INFO update_available no ;;
    3) pf_marker INFO update_available yes ;;
    4) pf_marker INFO update_available blocked ;;
    *) pf_marker INFO update_available unknown ;;
  esac
  return "$rc"
}

step_build() {
  timeout 900 ./build.sh -q
  local rc=$?
  # build.sh does not check the exit code of 'docker compose config', which
  # truncates docker-compose.yml on failure while build.sh still exits 0.
  # Trust the generated file, not the exit code.
  if [[ ! -s docker-compose.yml ]] || ! grep -q '^services:' docker-compose.yml; then
    echo "build: docker-compose.yml is missing, empty or has no services section"
    [[ "$rc" -eq 0 ]] && rc=1
  fi
  return "$rc"
}

# Print a PF|TAG line for every pacefactory image in the resolved compose file
# whose tag is not latest/latest-gpu (digest pins count as non-standard).
# Third-party images (mongo, nodered, ...) are ignored on purpose.
scan_tags() {
  awk '
    $1 == "image:" {
      ref = $2
      gsub(/^["\047]|["\047]$/, "", ref)
      if (ref !~ "(^|/)pacefactory/") next
      if (index(ref, "@") > 0) { print "PF|TAG|" ref; next }
      n = split(ref, p, "/")
      last = p[n]
      tag = (index(last, ":") > 0) ? substr(last, index(last, ":") + 1) : "latest"
      if (tag != "latest" && tag != "latest-gpu") print "PF|TAG|" ref
    }
  ' "$1"
}

step_tag_scan() {
  local file="docker-compose.yml"
  local tags="" count=0
  if [[ ! -f "$file" ]]; then
    echo "tag_scan: no $file here yet, skipping"
  else
    tags="$(scan_tags "$file")"
  fi
  if [[ -n "$tags" ]]; then
    count="$(printf '%s\n' "$tags" | grep -c '^PF|TAG|')"
    printf '\n%s\n' "$tags"
  fi
  pf_marker INFO nonstandard_tags "$count"
  return 0
}

step_update() {
  local tmp rc
  tmp="$(mktemp)" || return 1
  timeout 3600 ./update.sh -q 2>&1 | tee "$tmp"
  rc="${PIPESTATUS[0]}"
  # update.sh exits 0 even when the image pull fails (the up/migration block
  # is silently skipped in that case). "Deployment complete" only prints on
  # the success path, so use it as the success sentinel.
  if [[ "$rc" -eq 0 ]] && ! grep -q "Deployment complete" "$tmp"; then
    echo "update: update.sh exited 0 but never reported 'Deployment complete' (pull likely failed)"
    rc=21
  fi
  rm -f "$tmp"
  return "$rc"
}

# Derive the compose project name the same way update.sh does, in a subshell
# so nothing leaks into the payload environment.
get_project_name() {
  (
    QUIET_MODE=true
    [[ -f .settings ]] && . .settings >/dev/null 2>&1
    [[ -f scripts/common/projectName.sh ]] && . scripts/common/projectName.sh >/dev/null 2>&1
    printf '%s' "${PROJECT_NAME:-deployment-scripts}"
  )
}

step_health() {
  local delay="$1"
  if [[ "$delay" -gt 0 ]]; then
    echo "health: waiting ${delay}s for containers to settle"
    sleep "$delay"
  fi

  local project
  project="$(get_project_name)"
  pf_marker INFO project_name "$(printf '%s' "$project" | pf_clean)"

  local ps_out
  if ! ps_out="$(docker ps -a --filter "label=com.docker.compose.project=$project" --format '{{.Names}}\t{{.Status}}' 2>&1)"; then
    echo "health: docker ps failed: $ps_out"
    pf_marker INFO containers_up 0
    pf_marker INFO containers_total 0
    return 1
  fi

  local total=0 up=0 name status
  while IFS=$'\t' read -r name status; do
    [[ -z "$name" ]] && continue
    total=$((total + 1))
    if [[ "$status" == Up* && "$status" != *"(unhealthy)"* ]]; then
      up=$((up + 1))
    else
      pf_marker HEALTH "$(printf '%s' "$name" | pf_clean)" "$(printf '%s' "$status" | pf_clean)"
    fi
  done <<< "$ps_out"

  pf_marker INFO containers_up "$up"
  pf_marker INFO containers_total "$total"
  echo "health: $up/$total containers up"

  [[ "$total" -eq 0 ]] && return 1
  [[ "$up" -lt "$total" ]] && return 2
  return 0
}

# ---- modes -----------------------------------------------------------------

main_update() {
  run_step proxy step_proxy                  # warning only, never aborts
  run_step repo step_repo || return 11
  emit_tree_info
  if ! run_step fetch step_fetch; then
    [[ "$LAST_RC" -eq 17 ]] && return 17
    return 12
  fi
  run_step build step_build || return 13
  run_step tag_scan step_tag_scan            # report only, never aborts

  run_step update step_update
  local update_rc="$LAST_RC"

  run_step health step_health "$HEALTH_DELAY"
  local health_rc="$LAST_RC"

  [[ "$update_rc" -ne 0 ]] && return 14
  [[ "$health_rc" -eq 1 ]] && return 15
  [[ "$health_rc" -ge 2 ]] && return 16
  return 0
}

# Read-only preflight: connectivity, pending release, current tags and health.
main_check() {
  run_step proxy step_proxy
  run_step repo step_repo || return 11
  emit_tree_info
  run_step fetch step_fetch_check            # report only, never aborts
  run_step tag_scan step_tag_scan
  run_step health step_health 0
  return 0
}

main() {
  # One ordered output stream; ssh's own (local) stderr stays separate so the
  # orchestrator can tell transport problems from payload output.
  exec 2>&1

  local mode="update"
  [[ "$CHECK_MODE" == "true" ]] && mode="check"

  pf_marker BEGIN v2 "$(hostname | pf_clean)" "$(date +%s)"
  pf_marker INFO mode "$mode"

  if [[ "$mode" == "check" ]]; then
    main_check
  else
    main_update
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        CHECK_MODE=true
        ;;
      --health-delay)
        shift
        HEALTH_DELAY="${1:-15}"
        ;;
      *)
        echo "update-server.sh: ignoring unknown argument '$1'" >&2
        ;;
    esac
    shift 2>/dev/null || break
  done
  [[ "$HEALTH_DELAY" =~ ^[0-9]+$ ]] || HEALTH_DELAY=15
}

# ---- entry point -----------------------------------------------------------

# Offline test hook: print the PF|TAG lines for a given compose file and exit.
if [[ "${1:-}" == "--selftest-tagscan" ]]; then
  scan_tags "${2:?usage: --selftest-tagscan <compose-file>}"
  exit 0
fi

parse_args "$@"
main </dev/null
rc=$?
pf_marker END "$rc"
exit "$rc"
