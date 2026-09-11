#!/usr/bin/env bash
#
# stage.sh - assemble the release image staging directory.
#
#   scripts/release/stage.sh [--tag <tag>] [--image <repo>] [--out <dir>]
#
# Copies the files that ship in the deployment-scripts release image from
# `git ls-files` into <out> (default scripts/release/stage/, gitignored) and
# writes two metadata files:
#
#   <out>/.pf-release/MANIFEST   sorted, one path per line, relative to the
#                                install root (includes the two .pf-release files)
#   <out>/.pf-release/VERSION    KEY=VALUE lines: TAG, COMMIT, BUILT_AT, IMAGE
#
# What ships (the manifest), and nothing else:
#   build.sh update.sh record_cli.py stitch_cli.py LICENSE README.md .env.example
#   compose/           every tracked fragment
#   credentials/       tracked template files only (git ls-files never lists
#                      credentials.ini, keys or certificates: they are gitignored)
#   scripts/           minus scripts/docs/ and scripts/dev/
# Excluded on purpose: docs/, scv2_base_images/, CLAUDE.md, .claude/,
# .gitattributes, .gitignore, .github/. Anything in the image is readable by
# every customer machine token, so the rule is an allow-list: a new top-level
# path is excluded until it is added here.
set -euo pipefail

TAG=""
IMAGE="pacefactory/deployment-scripts"
OUT=""

usage() { sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)   TAG="${2:?--tag needs a value}"; shift 2 ;;
    --image) IMAGE="${2:?--image needs a value}"; shift 2 ;;
    --out)   OUT="${2:?--out needs a value}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo >&2 "stage.sh: unknown argument '$1'"; usage >&2; exit 2 ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo >&2 "stage.sh: $REPO_ROOT is not a git checkout"; exit 1; }

[[ -n "$OUT" ]] || OUT="$REPO_ROOT/scripts/release/stage"
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac

if [[ -z "$TAG" ]]; then
  # An exact tag when building a release, otherwise the branch name (CI passes
  # --tag from docker/metadata-action so the two always agree).
  TAG="$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD)"
fi
COMMIT="$(git rev-parse HEAD)"
BUILT_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ---- include rules ---------------------------------------------------------

# ship_path <repo-relative path>: 0 if the file belongs in the image
ship_path() {
  case "$1" in
    build.sh|update.sh|record_cli.py|stitch_cli.py|LICENSE|README.md|.env.example) return 0 ;;
    compose/*|credentials/*) return 0 ;;
    scripts/docs/*|scripts/dev/*) return 1 ;;
    scripts/*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- stage -----------------------------------------------------------------

# Refuse to wipe anything that does not look like a previous staging output.
if [[ -e "$OUT" && ! -d "$OUT/.pf-release" && -n "$(ls -A "$OUT" 2>/dev/null)" ]]; then
  echo >&2 "stage.sh: $OUT exists, is not empty and is not a previous stage/ (no .pf-release/); refusing to overwrite"
  exit 1
fi
rm -rf "$OUT"
mkdir -p "$OUT/.pf-release"

count=0
while IFS= read -r -d '' path; do
  ship_path "$path" || continue
  [[ -f "$path" ]] || { echo >&2 "stage.sh: tracked file missing from the checkout: $path"; exit 1; }
  mkdir -p "$OUT/$(dirname "$path")"
  cp -p "$path" "$OUT/$path"
  count=$((count + 1))
done < <(git ls-files -z)

{
  echo "TAG=$TAG"
  echo "COMMIT=$COMMIT"
  echo "BUILT_AT=$BUILT_AT"
  echo "IMAGE=$IMAGE"
} > "$OUT/.pf-release/VERSION"

# The manifest lists every file the image delivers, itself included, so the
# updater treats the metadata files like any other shipped file.
{
  (cd "$OUT" && find . -type f ! -path './.pf-release/*' -printf '%P\n')
  echo ".pf-release/MANIFEST"
  echo ".pf-release/VERSION"
} | LC_ALL=C sort > "$OUT/.pf-release/MANIFEST"

echo "staged $count files into $OUT"
echo "TAG=$TAG COMMIT=${COMMIT:0:12} IMAGE=$IMAGE"
