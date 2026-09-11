#!/usr/bin/env bash
#
# test-fetch-release.sh - offline unit test for the release tooling.
#
#   bash scripts/dev/test-fetch-release.sh
#
# Needs bash, git, coreutils. No Docker: it exercises fetch-release.sh --from
# (the sync engine) and stage.sh (the manifest rules); the docker pull/create/cp
# path is not covered here.
#
# Scenarios:
#   1. release install -> newer release: added / updated / removed / untouched
#      sets are exactly as expected, --check changes nothing and exits 3, the
#      second run is a no-op, executable bits follow the release.
#   2. git checkout conversion: refused with modified tracked files (exit 4),
#      then converts with `git ls-files` as the previous manifest, removes
#      excluded paths (docs/, CLAUDE.md, .gitignore), keeps .git unless
#      PF_REMOVE_GIT=true, never touches site files.
#   3. an unsafe manifest path is rejected.
#   4. stage.sh: the manifest matches the include/exclude rules (decision 7).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FETCH="$REPO_ROOT/scripts/release/fetch-release.sh"
STAGE="$REPO_ROOT/scripts/release/stage.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); echo "  ok   $*"; }
fail() { FAILS=$((FAILS + 1)); echo "  FAIL $*"; }
assert_eq() { if [[ "$1" == "$2" ]]; then pass "$3"; else fail "$3: expected '$2', got '$1'"; fi; }
assert_file() { if [[ -f "$1" ]]; then pass "exists: ${1#"$WORK"/}"; else fail "missing: ${1#"$WORK"/}"; fi; }
assert_absent() { if [[ ! -e "$1" ]]; then pass "absent: ${1#"$WORK"/}"; else fail "should be absent: ${1#"$WORK"/}"; fi; }
assert_content() { if [[ "$(cat "$1")" == "$2" ]]; then pass "content: ${1#"$WORK"/}"; else fail "content of ${1#"$WORK"/}: got '$(cat "$1")'"; fi; }
assert_exec() { if [[ -x "$1" ]]; then pass "executable: ${1#"$WORK"/}"; else fail "not executable: ${1#"$WORK"/}"; fi; }
assert_not_exec() { if [[ ! -x "$1" ]]; then pass "not executable: ${1#"$WORK"/}"; else fail "should not be executable: ${1#"$WORK"/}"; fi; }

# mkrel <dir> <tag> : finish a release tree: VERSION + MANIFEST from its files
mkrel() {
  local dir="$1" tag="$2"
  mkdir -p "$dir/.pf-release"
  printf 'TAG=%s\nCOMMIT=%s\nBUILT_AT=2026-01-01T00:00:00Z\nIMAGE=pacefactory/deployment-scripts\n' "$tag" "$(printf '%040d' "${#tag}")" > "$dir/.pf-release/VERSION"
  { (cd "$dir" && find . -type f ! -path './.pf-release/*' -printf '%P\n'); echo .pf-release/MANIFEST; echo .pf-release/VERSION; } | LC_ALL=C sort > "$dir/.pf-release/MANIFEST"
}
# snapshot <dir>: content+mode listing for change detection
snapshot() { (cd "$1" && find . -type f -printf '%P %m\n' | LC_ALL=C sort | while read -r p m; do printf '%s %s %s\n' "$p" "$m" "$(md5sum < "$p" | cut -c1-32)"; done); }
# run <expected rc> <args...>: run fetch-release with PF_INSTALL_DIR=$INSTALL, capture output in $OUT
run() { local want="$1"; shift; local rc=0; OUT="$(PF_INSTALL_DIR="$INSTALL" bash "$FETCH" "$@" 2>&1)" || rc=$?; assert_eq "$rc" "$want" "exit code of fetch-release $*"; }
# grep_out <pattern> <label>
grep_out() { if grep -q -- "$1" <<<"$OUT"; then pass "$2"; else fail "$2 (pattern '$1' not in output)"; printf '      | %s\n' "$OUT"; fi; }

echo "== 1. release install -> newer release"
REL_A="$WORK/rel-a"; REL_B="$WORK/rel-b"; INSTALL="$WORK/install"
mkdir -p "$REL_A/compose" "$REL_A/scripts/remote"
printf '#!/bin/bash\necho v1\n' > "$REL_A/build.sh"; chmod 755 "$REL_A/build.sh"
echo "base v1" > "$REL_A/compose/docker-compose.base.yml"
echo "stale" > "$REL_A/compose/docker-compose.stale.yml"
echo "x v1" > "$REL_A/scripts/x.sh"; chmod 644 "$REL_A/scripts/x.sh"
echo "template" > "$REL_A/scripts/remote/servers.example.txt"
mkrel "$REL_A" v1.0.0

# The installed tree: release A plus everything a site adds.
cp -a "$REL_A" "$INSTALL"
echo "SERVER_NAME=site.example.com" > "$INSTALL/.env"
echo "custom fragment" > "$INSTALL/compose/docker-compose.custom.yml"
echo "client fragment" > "$INSTALL/compose/docker-compose.client-specific-custom.yml"
echo "settings" > "$INSTALL/.settings"
echo "built" > "$INSTALL/docker-compose.yml"
mkdir -p "$INSTALL/credentials/godaddy"; echo "secret" > "$INSTALL/credentials/godaddy/credentials.ini"
echo "host1" > "$INSTALL/scripts/remote/servers.txt"

mkdir -p "$REL_B/compose" "$REL_B/scripts/remote"
printf '#!/bin/bash\necho v2\n' > "$REL_B/build.sh"; chmod 755 "$REL_B/build.sh"
echo "base v1" > "$REL_B/compose/docker-compose.base.yml"          # unchanged
echo "new fragment" > "$REL_B/compose/docker-compose.new.yml"     # added
echo "x v1" > "$REL_B/scripts/x.sh"; chmod 755 "$REL_B/scripts/x.sh"  # mode-only change
echo "template" > "$REL_B/scripts/remote/servers.example.txt"     # unchanged
mkrel "$REL_B" v1.1.0

before="$(snapshot "$INSTALL")"
run 3 --check --from "$REL_B"
assert_eq "$(snapshot "$INSTALL")" "$before" "--check changed nothing"
grep_out "Release: v1.0.0 (0000000) -> v1.1.0 (0000000)" "--check reports versions"
grep_out "Would change: added 1, updated 4, removed 1, unchanged 2" "--check counts"
grep_out "Update available" "--check says update available"

run 0 --from "$REL_B"
grep_out "Synced: added 1, updated 4, removed 1, unchanged 2" "sync counts"
grep_out "  A compose/docker-compose.new.yml" "added list"
grep_out "  U build.sh" "updated: build.sh"
grep_out "  U scripts/x.sh" "updated: mode-only change"
grep_out "  U .pf-release/MANIFEST" "updated: manifest"
grep_out "  U .pf-release/VERSION" "updated: version"
grep_out "  D compose/docker-compose.stale.yml" "removed: stale fragment"
grep_out "Next steps" "prints next steps"
grep_out "./build.sh" "next steps name build.sh"
assert_content "$INSTALL/build.sh" "$(printf '#!/bin/bash\necho v2')"
assert_exec "$INSTALL/build.sh"
assert_exec "$INSTALL/scripts/x.sh"
assert_file "$INSTALL/compose/docker-compose.new.yml"
assert_absent "$INSTALL/compose/docker-compose.stale.yml"
assert_content "$INSTALL/.env" "SERVER_NAME=site.example.com"
assert_content "$INSTALL/compose/docker-compose.custom.yml" "custom fragment"
assert_content "$INSTALL/compose/docker-compose.client-specific-custom.yml" "client fragment"
assert_content "$INSTALL/.settings" "settings"
assert_content "$INSTALL/docker-compose.yml" "built"
assert_content "$INSTALL/credentials/godaddy/credentials.ini" "secret"
assert_content "$INSTALL/scripts/remote/servers.txt" "host1"
assert_eq "$(sed -n 's/^TAG=//p' "$INSTALL/.pf-release/VERSION")" "v1.1.0" "installed VERSION tag"
assert_absent "$INSTALL/compose/.docker-compose.new.yml.pf-tmp"
if [[ -z "$(find "$INSTALL" -name '*.pf-tmp')" ]]; then pass "no temp files left"; else fail "temp files left behind"; fi

after="$(snapshot "$INSTALL")"
run 0 --from "$REL_B"
grep_out "Synced: added 0, updated 0, removed 0, unchanged 7" "second run is a no-op"
assert_eq "$(snapshot "$INSTALL")" "$after" "second run changed nothing"
run 0 --check --from "$REL_B"
grep_out "Up to date" "--check up to date"

echo "== 1b. site-modified shipped file is overwritten by a later release (release is authoritative)"
echo "local edit" > "$INSTALL/scripts/x.sh"
run 0 --from "$REL_B"
grep_out "  U scripts/x.sh" "locally edited shipped file is restored"

echo "== 2. git checkout conversion"
INSTALL="$WORK/checkout"
mkdir -p "$INSTALL/compose" "$INSTALL/docs/how-to" "$INSTALL/scripts/remote"
(
  cd "$INSTALL"
  git init -q -b main .
  git config user.email t@example.com; git config user.name t
  printf '#!/bin/bash\necho v0\n' > build.sh; chmod 755 build.sh
  echo "base v1" > compose/docker-compose.base.yml
  echo "stale" > compose/docker-compose.stale.yml
  echo "docs" > docs/how-to/x.md
  echo "claude" > CLAUDE.md
  printf '.env\n' > .gitignore
  echo "x v0" > scripts/x.sh
  echo "template" > scripts/remote/servers.example.txt
  git add -A && git commit -q -m init
  echo "SERVER_NAME=site" > .env                       # untracked site file
  echo "custom fragment" > compose/docker-compose.custom.yml
  echo "host1" > scripts/remote/servers.txt
)
echo "modified locally" >> "$INSTALL/build.sh"          # modified tracked file
before="$(snapshot "$INSTALL")"
run 4 --from "$REL_B"
grep_out "refusing to convert" "conversion refused"
grep_out " M build.sh" "names the modified file"
assert_eq "$(snapshot "$INSTALL")" "$before" "refused conversion changed nothing"
run 4 --check --from "$REL_B"
grep_out "Conversion would be refused" "--check reports the refusal"
(cd "$INSTALL" && git checkout -q -- build.sh)
run 0 --from "$REL_B"
grep_out "Converting git checkout" "conversion announced"
grep_out "Release: git checkout .* on main -> v1.1.0 (0000000)" "conversion reports the git state as before"
grep_out "  D docs/how-to/x.md" "removed: docs"
grep_out "  D CLAUDE.md" "removed: CLAUDE.md"
grep_out "  D .gitignore" "removed: .gitignore"
grep_out "  D compose/docker-compose.stale.yml" "removed: stale fragment"
grep_out "  A .pf-release/MANIFEST" "added: manifest"
grep_out ".git left in place" "keeps .git by default"
assert_absent "$INSTALL/docs"
assert_absent "$INSTALL/CLAUDE.md"
if [[ -d "$INSTALL/.git" ]]; then pass ".git kept"; else fail ".git removed without PF_REMOVE_GIT"; fi
assert_content "$INSTALL/.env" "SERVER_NAME=site"
assert_content "$INSTALL/compose/docker-compose.custom.yml" "custom fragment"
assert_content "$INSTALL/scripts/remote/servers.txt" "host1"
assert_content "$INSTALL/build.sh" "$(printf '#!/bin/bash\necho v2')"
assert_exec "$INSTALL/scripts/x.sh"
rc=0; OUT="$(PF_INSTALL_DIR="$INSTALL" PF_REMOVE_GIT=true bash "$FETCH" --from "$REL_B" 2>&1)" || rc=$?
assert_eq "$rc" 0 "PF_REMOVE_GIT run exit code"
grep_out "Removed .*/.git" "PF_REMOVE_GIT removes .git"
assert_absent "$INSTALL/.git"
grep_out "Synced: added 0, updated 0, removed 0" "conversion result is a complete release install"

echo "== 3. unsafe manifest path"
REL_EVIL="$WORK/rel-evil"; mkdir -p "$REL_EVIL/.pf-release"
printf 'TAG=x\nCOMMIT=x\nBUILT_AT=x\nIMAGE=x\n' > "$REL_EVIL/.pf-release/VERSION"
printf '../evil\n.pf-release/MANIFEST\n.pf-release/VERSION\n' > "$REL_EVIL/.pf-release/MANIFEST"
INSTALL="$WORK/install3"; mkdir -p "$INSTALL"
run 1 --from "$REL_EVIL"
grep_out "unsafe path" "rejects ../ in manifest"
assert_absent "$WORK/evil"

echo "== 3b. source and install dir must differ / --from must be a release tree"
INSTALL="$REL_B"; run 1 --from "$REL_B"; grep_out "same" "refuses src == dst"
INSTALL="$WORK/install3"; run 1 --from "$WORK"; grep_out "not a deployment-scripts release tree" "refuses non-release --from"

echo "== 4. stage.sh manifest against the include/exclude rules"
STAGE_OUT="$WORK/stage"
if (cd "$REPO_ROOT" && bash "$STAGE" --out "$STAGE_OUT" --tag test --image pacefactory/deployment-scripts >/dev/null); then
  pass "stage.sh ran"
  M="$STAGE_OUT/.pf-release/MANIFEST"
  expected="$( { cd "$REPO_ROOT" && git ls-files | grep -E '^(build\.sh|update\.sh|record_cli\.py|stitch_cli\.py|LICENSE|README\.md|\.env\.example|compose/.*|credentials/.*|scripts/.*)$' | grep -Ev '^scripts/(docs|dev)/'; echo .pf-release/MANIFEST; echo .pf-release/VERSION; } | LC_ALL=C sort)"
  assert_eq "$(cat "$M")" "$expected" "manifest equals git ls-files filtered by the decision-7 rules"
  if grep -Eq '^(docs/|scv2_base_images/|CLAUDE\.md$|\.claude/|\.gitattributes$|\.gitignore$|\.github/|scripts/docs/|scripts/dev/)' "$M"; then fail "manifest contains excluded paths"; else pass "no excluded paths in manifest"; fi
  for must in build.sh update.sh .env.example compose/docker-compose.base.yml scripts/common/dockerLogin.sh scripts/release/fetch-release.sh scripts/remote/update-server.sh; do
    if grep -qx "$must" "$M"; then pass "manifest has $must"; else fail "manifest lacks $must (is it committed? stage.sh reads git ls-files)"; fi
  done
  miss=0; while IFS= read -r p; do [[ -f "$STAGE_OUT/$p" ]] || { miss=1; fail "manifest entry not staged: $p"; }; done < "$M"
  [[ "$miss" -eq 0 ]] && pass "every manifest entry exists in stage/"
  extra="$(cd "$STAGE_OUT" && find . -type f -printf '%P\n' | LC_ALL=C sort | comm -23 - "$M")"
  assert_eq "$extra" "" "no staged file is missing from the manifest"
  assert_exec "$STAGE_OUT/build.sh"
  assert_eq "$(sed -n 's/^TAG=//p' "$STAGE_OUT/.pf-release/VERSION")" "test" "VERSION TAG from --tag"
  assert_eq "$(sed -n 's/^IMAGE=//p' "$STAGE_OUT/.pf-release/VERSION")" "pacefactory/deployment-scripts" "VERSION IMAGE"
  assert_eq "$(sed -n 's/^COMMIT=//p' "$STAGE_OUT/.pf-release/VERSION")" "$(git -C "$REPO_ROOT" rev-parse HEAD)" "VERSION COMMIT"
  if grep -q '^BUILT_AT=20' "$STAGE_OUT/.pf-release/VERSION"; then pass "VERSION BUILT_AT"; else fail "VERSION BUILT_AT"; fi
else
  fail "stage.sh failed"
fi

echo
echo "passed $PASSES, failed $FAILS"
[[ "$FAILS" -eq 0 ]]
