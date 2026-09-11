#!/usr/bin/env bash
#
# fetch-release.sh - fetch a deployment-scripts release and sync it into the
# install directory. This is the in-tree updater: it replaces `git pull`.
#
#   scripts/release/fetch-release.sh [--check] [--from <extracted-dir>]
#
# Modes:
#   default        docker pull ${PF_IMAGE}:${PF_RELEASE}, extract it with
#                  docker create + docker cp into a temp dir next to the install
#                  dir, sync, clean up (also on failure).
#   --from <dir>   sync from an already extracted release tree (the public
#                  bootstrap install.sh calls this after doing the pull itself).
#   --check        report what would change and exit 3 if an update is
#                  available, 0 if up to date; nothing is written.
#
# Environment:
#   PF_INSTALL_DIR  install root; default: the tree this script lives in
#                   (<root>/scripts/release/fetch-release.sh -> <root>)
#   PF_IMAGE        default pacefactory/deployment-scripts
#   PF_RELEASE      tag to fetch, default latest (PF_RELEASE=v1.2.3 pins or rolls back)
#   PF_REMOVE_GIT   true to delete a converted checkout's .git directory after a
#                   successful sync; default false (left alone)
#   PF_OAT_FILE     Docker Hub token file, default $HOME/scv2/docker_oat.sh; used
#                   only to retry once when the pull fails (scripts/common/dockerLogin.sh)
#
# Sync rule (manifest-based, never wholesale):
#   - every file in the new .pf-release/MANIFEST is copied (executable bits kept)
#   - a file is deleted only if it is in the previous manifest and absent from
#     the new one
#   - everything else is left alone: .env, .settings, docker-compose.yml,
#     credentials, SSL material, servers.txt, site-specific compose fragments
#     such as compose/docker-compose.custom.yml, and anything else the site added
#   The previous manifest is .pf-release/MANIFEST if present, else `git ls-files`
#   when the install dir is still a git checkout (first conversion), else empty.
#   A first conversion is refused while the checkout has modified tracked files.
#
# Exit codes:
#   0  synced (or --check: up to date)
#   1  error (pull, extract, sync)
#   2  usage
#   3  --check: an update is available
#   4  conversion refused: the git checkout has modified tracked files
#
# No sudo. Idempotent. Safe from any cwd. Never runs build.sh or update.sh: it
# prints them as the next steps. Files are replaced by rename (copy to a temp
# name, then mv) so this script can update itself while running.
set -euo pipefail

PF_IMAGE="${PF_IMAGE:-pacefactory/deployment-scripts}"
PF_RELEASE="${PF_RELEASE:-latest}"
PF_REMOVE_GIT="${PF_REMOVE_GIT:-false}"
PF_OAT_FILE="${PF_OAT_FILE:-$HOME/scv2/docker_oat.sh}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FROM_DIR=""
CHECK_MODE=false
INSTALL_DIR=""
TMP_DIR=""
CONTAINER_ID=""
CONVERTING=false

EXIT_UPDATE_AVAILABLE=3
EXIT_CONVERSION_REFUSED=4

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }
log()   { printf '%s\n' "$*"; }
die()   { printf 'fetch-release: %s\n' "$*" >&2; exit 1; }

# ---- cleanup ---------------------------------------------------------------

# shellcheck disable=SC2329  # invoked via trap
cleanup() {
  if [[ -n "$CONTAINER_ID" ]]; then
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
    CONTAINER_ID=""
  fi
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
    TMP_DIR=""
  fi
}

# ---- arguments -------------------------------------------------------------

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)  FROM_DIR="${2:?--from needs a directory}"; shift 2 ;;
      --check) CHECK_MODE=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo >&2 "fetch-release: unknown argument '$1'"; usage >&2; exit 2 ;;
    esac
  done
}

resolve_install_dir() {
  if [[ -n "${PF_INSTALL_DIR:-}" ]]; then
    INSTALL_DIR="$PF_INSTALL_DIR"
  else
    INSTALL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
  fi
  case "$INSTALL_DIR" in /*) ;; *) INSTALL_DIR="$PWD/$INSTALL_DIR" ;; esac
  INSTALL_DIR="${INSTALL_DIR%/}"
}

# ---- pull and extract (default mode) ---------------------------------------

pull_image() {
  local ref="$PF_IMAGE:$PF_RELEASE"
  log "Pulling $ref ..."
  if docker pull --quiet "$ref" >/dev/null; then
    return 0
  fi
  if [[ -f "$PF_OAT_FILE" ]]; then
    log "Pull failed; logging in with $PF_OAT_FILE and retrying once"
    # shellcheck source=scripts/common/dockerLogin.sh
    source "$SCRIPT_DIR/../common/dockerLogin.sh"
    if pf_docker_login_from_file "$PF_OAT_FILE" && docker pull --quiet "$ref" >/dev/null; then
      return 0
    fi
  fi
  cat >&2 <<EOF
fetch-release: could not pull $ref.
  This server's Docker Hub token may have been revoked, may lack image-pull
  scope on $PF_IMAGE, or the release '$PF_RELEASE' may not exist.
  The token lives in $PF_OAT_FILE (see the Pacefactory Deployment Guide); the
  server must stay logged in as 'pacefactory'. Repair with:
    curl -fsSL https://get.pacefactory.dev/install.sh | bash
EOF
  return 1
}

extract_image() {
  local ref="$PF_IMAGE:$PF_RELEASE"
  # The image is FROM scratch with no command; docker create needs one but
  # never runs it.
  CONTAINER_ID="$(docker create "$ref" /pf-release)" || die "docker create $ref failed"
  docker cp "$CONTAINER_ID:/." "$TMP_DIR/" || die "docker cp from $ref failed"
  docker rm -f "$CONTAINER_ID" >/dev/null
  CONTAINER_ID=""
}

# ---- manifests -------------------------------------------------------------

# Reject anything that could escape the install dir.
check_manifest_path() {
  local p="$1"
  [[ -n "$p" ]] || die "manifest contains an empty path"
  case "/$p/" in
    //*|*/../*|*/./*|*'|'*|*$'\n'*) die "manifest contains an unsafe path: $p" ;;
  esac
}

# read_version <root> <KEY>: value of KEY from <root>/.pf-release/VERSION ('' if absent)
read_version() {
  local f="$1/.pf-release/VERSION"
  [[ -f "$f" ]] || return 0
  sed -n "s/^$2=//p" "$f" | head -1
}

describe_tree() {
  local root="$1" tag commit
  tag="$(read_version "$root" TAG)"
  commit="$(read_version "$root" COMMIT)"
  if [[ -n "$tag" ]]; then
    printf '%s (%s)' "$tag" "${commit:0:7}"
  elif [[ -d "$root/.git" ]] && command -v git >/dev/null 2>&1; then
    printf 'git checkout %s on %s' \
      "$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo '?')" \
      "$(git -C "$root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  elif [[ -d "$root/.git" ]]; then
    printf 'git checkout (git command not available)'
  else
    printf 'none (fresh install)'
  fi
}

# Previous manifest to stdout, one path per line.
previous_manifest() {
  local root="$1"
  if [[ -f "$root/.pf-release/MANIFEST" ]]; then
    cat "$root/.pf-release/MANIFEST"
  elif [[ -d "$root/.git" ]]; then
    git -C "$root" ls-files
  fi
}

# Executable bit equality plus byte equality.
files_same() {
  local a="$1" b="$2" xa=0 xb=0
  [[ -x "$a" ]] && xa=1
  [[ -x "$b" ]] && xb=1
  [[ "$xa" -eq "$xb" ]] && cmp -s "$a" "$b"
}

# ---- sync ------------------------------------------------------------------

ADDED=(); UPDATED=(); REMOVED=(); UNCHANGED=0

plan_sync() {
  local src="$1" dst="$2" p
  local -A in_new=()

  [[ -f "$src/.pf-release/MANIFEST" ]] || die "$src is not a deployment-scripts release tree (no .pf-release/MANIFEST)"

  # First conversion of a git checkout: the previous manifest is `git ls-files`.
  # Decided here, not inside previous_manifest, which runs in a subshell.
  if [[ ! -f "$dst/.pf-release/MANIFEST" && -d "$dst/.git" ]]; then
    command -v git >/dev/null 2>&1 || die "$dst is a git checkout but 'git' is not installed; cannot compute the previous manifest"
    CONVERTING=true
  fi

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    check_manifest_path "$p"
    in_new[$p]=1
    [[ -f "$src/$p" ]] || die "manifest lists '$p' but the release tree does not contain it"
    if [[ ! -e "$dst/$p" ]]; then
      ADDED+=("$p")
    elif files_same "$src/$p" "$dst/$p"; then
      UNCHANGED=$((UNCHANGED + 1))
    else
      UPDATED+=("$p")
    fi
  done < "$src/.pf-release/MANIFEST"

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    [[ -n "${in_new[$p]:-}" ]] && continue
    check_manifest_path "$p"
    [[ -e "$dst/$p" ]] && REMOVED+=("$p")
  done < <(previous_manifest "$dst")
}

# Modified tracked files in a checkout would be silently overwritten by the
# release; refuse the first conversion until the operator has dealt with them.
check_conversion() {
  local dst="$1" modified
  [[ "$CONVERTING" == "true" ]] || return 0
  modified="$(git -C "$dst" status --porcelain --untracked-files=no 2>/dev/null || true)"
  [[ -z "$modified" ]] && return 0
  {
    echo "fetch-release: refusing to convert the git checkout at $dst:"
    echo "  it has modified tracked files that the release would overwrite:"
    printf '    %s\n' "$modified"
    echo "  Commit, stash ('git stash') or revert ('git checkout -- <file>') them, then re-run."
  } >&2
  return 1
}

apply_sync() {
  local src="$1" dst="$2" p d tmp
  for p in ${ADDED[@]+"${ADDED[@]}"} ${UPDATED[@]+"${UPDATED[@]}"}; do
    d="$(dirname "$dst/$p")"
    mkdir -p "$d"
    tmp="$d/.$(basename "$p").pf-tmp"
    cp -p "$src/$p" "$tmp"
    mv -f "$tmp" "$dst/$p"
  done
  for p in ${REMOVED[@]+"${REMOVED[@]}"}; do
    rm -f "$dst/$p"
    d="$(dirname "$p")"
    while [[ "$d" != "." && "$d" != "/" ]]; do
      rmdir "$dst/$d" 2>/dev/null || break
      d="$(dirname "$d")"
    done
  done
}

print_plan() {
  local verb="$1" p
  log "Release: $2 -> $3"
  log "$verb: added ${#ADDED[@]}, updated ${#UPDATED[@]}, removed ${#REMOVED[@]}, unchanged $UNCHANGED"
  for p in ${ADDED[@]+"${ADDED[@]}"};   do log "  A $p"; done
  for p in ${UPDATED[@]+"${UPDATED[@]}"}; do log "  U $p"; done
  for p in ${REMOVED[@]+"${REMOVED[@]}"}; do log "  D $p"; done
}

sync_tree() {
  local src="$1" dst="$2" before after changes
  before="$(describe_tree "$dst")"
  after="$(describe_tree "$src")"

  plan_sync "$src" "$dst"
  changes=$(( ${#ADDED[@]} + ${#UPDATED[@]} + ${#REMOVED[@]} ))

  if [[ "$CHECK_MODE" == "true" ]]; then
    print_plan "Would change" "$before" "$after"
    if ! check_conversion "$dst"; then
      log "Conversion would be refused (see above)."
      return "$EXIT_CONVERSION_REFUSED"
    fi
    if [[ "$changes" -eq 0 ]]; then
      log "Up to date."
      return 0
    fi
    log "Update available."
    return "$EXIT_UPDATE_AVAILABLE"
  fi

  check_conversion "$dst" || return "$EXIT_CONVERSION_REFUSED"
  [[ "$CONVERTING" == "true" ]] && log "Converting git checkout at $dst to a release install (previous manifest: git ls-files)"
  apply_sync "$src" "$dst"
  print_plan "Synced" "$before" "$after"

  if [[ -d "$dst/.git" ]]; then
    if [[ "$PF_REMOVE_GIT" == "true" ]]; then
      rm -rf "$dst/.git"
      log "Removed $dst/.git (PF_REMOVE_GIT=true)"
    else
      log "Note: $dst/.git left in place (set PF_REMOVE_GIT=true to remove it); git commands there are no longer meaningful."
    fi
  fi

  cat <<EOF

deployment-scripts release $(read_version "$dst" TAG) is installed in $dst.
Next steps (not run by this script):
  cd $dst
  ./build.sh            # ./build.sh -q keeps the current selection
  ./update.sh           # ./update.sh -q --pull true --logout false for non-interactive use
EOF
  return 0
}

# ---- entry point -----------------------------------------------------------

main() {
  local src rc
  parse_args "$@"
  resolve_install_dir
  trap cleanup EXIT INT TERM

  if [[ -n "$FROM_DIR" ]]; then
    [[ -d "$FROM_DIR" ]] || die "--from: $FROM_DIR is not a directory"
    src="$(cd "$FROM_DIR" && pwd)"
    [[ -f "$src/.pf-release/MANIFEST" ]] || die "$src is not a deployment-scripts release tree (no .pf-release/MANIFEST)"
  else
    command -v docker >/dev/null 2>&1 || die "docker not found on PATH"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    pull_image || exit 1
    TMP_DIR="$(mktemp -d "$(dirname "$INSTALL_DIR")/.deployment-scripts-release.XXXXXX")"
    extract_image
    src="$TMP_DIR"
  fi

  mkdir -p "$INSTALL_DIR"
  [[ "$(cd "$INSTALL_DIR" && pwd -P)" != "$(cd "$src" && pwd -P)" ]] || die "source tree and install dir are the same ($INSTALL_DIR); set PF_INSTALL_DIR"

  rc=0
  sync_tree "$src" "$INSTALL_DIR" || rc=$?
  return "$rc"
}

main "$@"
exit $?
