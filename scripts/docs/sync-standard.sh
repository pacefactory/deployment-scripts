#!/bin/bash
#
# sync-standard.sh [--check] [--commit] <service-repo-checkout>...
#
# Copies the canonical docs/DOCUMENTATION_STANDARD.md from this repository into
# each service repo checkout as docs/DOCUMENTATION_STANDARD.md, with one banner
# comment inserted directly after the YAML header:
#
#   <!-- VENDORED COPY: do not edit. Canonical: <url>. Version <v>.
#        Synced from pacefactory/deployment-scripts <sha> on <date> by
#        scripts/docs/sync-standard.sh. -->
#
# Everything else is byte-identical to the canonical file (service-repo
# standard §11).
#
#   --check   do not write; strip the banner from each copy and diff it against
#             the canonical file. Exit 1 if any copy is missing or differs.
#   --commit  after writing, commit the copy in the target checkout on the
#             current branch (message "docs: sync documentation standard <sha>").
#             Nothing is pushed.
#
# Run from the deployment-scripts repository root. The target checkouts are
# local paths; obtaining them (git clone) is left to the caller so this script
# works with whatever credentials the operator or CI job has.

set -euo pipefail

CANONICAL="docs/DOCUMENTATION_STANDARD.md"
CANONICAL_URL="https://github.com/pacefactory/deployment-scripts/blob/main/docs/DOCUMENTATION_STANDARD.md"
TARGET_REL="docs/DOCUMENTATION_STANDARD.md"
BANNER_PREFIX="<!-- VENDORED COPY: do not edit."

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
[[ -f "$CANONICAL" && -f build.sh ]] || { echo >&2 "run from the deployment-scripts repository root"; exit 2; }

CHECK=0; COMMIT=0; TARGETS=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK=1 ;;
    --commit) COMMIT=1 ;;
    -h|--help) usage 0 ;;
    -*) echo >&2 "unknown option $arg"; usage 2 ;;
    *) TARGETS+=("$arg") ;;
  esac
done
[[ ${#TARGETS[@]} -gt 0 ]] || usage 2

sha="$(git rev-parse --short HEAD)"
version="$(grep -m1 '^Version:' "$CANONICAL" | sed 's/^Version:[[:space:]]*//')"
today="$(date -u +%Y-%m-%d)"
banner="$BANNER_PREFIX Canonical: $CANONICAL_URL. Version $version. Synced from pacefactory/deployment-scripts $sha on $today by scripts/docs/sync-standard.sh. -->"

# header_end <file>: line number of the closing '---' of the YAML front matter
header_end() { awk 'NR==1 && $0!="---" {print 0; exit} NR>1 && $0=="---" {print NR; exit}' "$1"; }

# render_copy: canonical file with the banner inserted after the front matter
render_copy() {
  local end; end="$(header_end "$CANONICAL")"
  [[ "$end" -gt 0 ]] || { echo >&2 "$CANONICAL has no YAML front matter"; exit 2; }
  sed -n "1,${end}p" "$CANONICAL"
  echo "$banner"
  sed -n "$((end+1)),\$p" "$CANONICAL"
}

# strip_banner <file>: the copy without its banner line, for diffing
strip_banner() { grep -v -F "$BANNER_PREFIX" "$1"; }

rc=0
for repo in "${TARGETS[@]}"; do
  target="$repo/$TARGET_REL"
  if [[ ! -d "$repo" ]]; then echo "FAIL $repo: not a directory"; rc=1; continue; fi
  if (( CHECK )); then
    if [[ ! -f "$target" ]]; then echo "FAIL $repo: $TARGET_REL missing"; rc=1; continue; fi
    if ! grep -q -F "$BANNER_PREFIX" "$target"; then echo "FAIL $repo: $TARGET_REL has no vendored-copy banner"; rc=1; continue; fi
    if diff -u "$CANONICAL" <(strip_banner "$target") >"/tmp/sync-standard.$$.diff"; then
      echo "ok   $repo: $TARGET_REL matches canonical ($(grep -o 'Synced from [^ ]* [0-9a-f]*' "$target" | head -1))"
    else
      echo "FAIL $repo: $TARGET_REL differs from canonical:"; sed -n '1,40p' "/tmp/sync-standard.$$.diff"; rc=1
    fi
    rm -f "/tmp/sync-standard.$$.diff"
    continue
  fi
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]] && diff -q "$CANONICAL" <(strip_banner "$target") >/dev/null 2>&1; then
    echo "ok   $repo: already up to date; refreshing banner only"
  fi
  render_copy > "$target"
  echo "wrote $target"
  if (( COMMIT )); then
    if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -C "$repo" add "$TARGET_REL"
      if git -C "$repo" diff --cached --quiet -- "$TARGET_REL"; then echo "     $repo: nothing to commit"
      else git -C "$repo" commit -q -m "docs: sync documentation standard $sha" -- "$TARGET_REL" && echo "     $repo: committed"; fi
    else
      echo "FAIL $repo: not a git checkout, cannot --commit"; rc=1
    fi
  fi
  grep -q -F "($TARGET_REL#" "$repo/docs/README.md" 2>/dev/null || grep -q -F "(DOCUMENTATION_STANDARD.md)" "$repo/docs/README.md" 2>/dev/null \
    || echo "     note: add $TARGET_REL to $repo/docs/README.md (service-repo standard §11)"
done
exit $rc
