#!/bin/bash
# check-docs.sh [--mermaid]
# Mechanical checks from the documentation standards:
#   - every .md under docs/ has the YAML header with the required fields
#   - every .mmd under docs/ has the '%% derived_from:' / '%% last_verified:' comment header
#   - every file under docs/ is listed in docs/README.md
#   - every local path in derived_from exists (globs allowed; URLs skipped)
#   - generated docs are not hand-edited: 'regenerate.sh --check' is a separate step
#   --mermaid: additionally parse every .mmd and every ```mermaid block with mmdc
#              (MMDC=<path to mmdc>, MMDC_PUPPETEER_CONFIG=<json> for a custom Chromium)
set -uo pipefail
cd "$(dirname "$0")/../.."
FAILS="$(mktemp)"
fail() { echo "FAIL: $*"; echo 1 >> "$FAILS"; }

index="docs/README.md"
[[ -f "$index" ]] || { echo "FAIL: $index missing"; exit 1; }

while IFS= read -r f; do
  rel="${f#docs/}"
  case "$f" in
    *.md)
      head -1 "$f" | grep -q '^---$' || fail "$f: no YAML header"
      for k in title type derived_from last_verified verified_against; do
        sed -n '2,/^---$/p' "$f" | grep -q "^$k:" || fail "$f: header missing '$k'"
      done
      sed -n '2,/^---$/p' "$f" | grep -q '^type: \(reference\|how-to\|example\|standard\|other\)$' || fail "$f: header type not in the allowed set"
      # derived_from paths
      sed -n '2,/^---$/p' "$f" | sed -n '/^derived_from:/,/^[a-z_]*:/p' | grep '^  - ' | sed 's/^  - //' | while read -r d; do
        [[ "$d" == http* ]] && continue
        compgen -G "$d" >/dev/null 2>&1 || fail "$f: derived_from path does not exist: $d"
      done
      ;;
    *.mmd)
      head -1 "$f" | grep -q '^%% derived_from:' || fail "$f: missing '%% derived_from:' header"
      grep -q '^%% last_verified:' "$f" || fail "$f: missing '%% last_verified:' header"
      ;;
  esac
  # index coverage (README itself excepted); hidden files matched by name
  if [[ "$f" != "$index" ]]; then
    grep -qF "($rel)" "$index" || grep -qF "/$(basename "$f"))" "$index" || fail "$f: not listed in docs/README.md"
  fi
done < <(find docs -type f \( -name '*' \) | sort)

# colocated READMEs listed in index.tsv must exist
awk -F'\t' '!/^#/ && $1 !~ /^docs\// {print $1}' scripts/docs/index.tsv | while read -r f; do [[ -f "$f" ]] || fail "index.tsv lists missing file $f"; done

if [[ "${1:-}" == "--mermaid" ]]; then
  MMDC="${MMDC:-mmdc}"
  if ! command -v "$MMDC" >/dev/null 2>&1; then fail "mmdc not found (set MMDC=/path/to/mmdc)"; else
  tmp="$(mktemp -d)"
  pargs=(); [[ -n "${MMDC_PUPPETEER_CONFIG:-}" ]] && pargs=(-p "$MMDC_PUPPETEER_CONFIG")
  n=0
  for f in $(find docs -name '*.mmd' | sort); do
    n=$((n+1)); "$MMDC" "${pargs[@]}" -i "$f" -o "$tmp/out.svg" >/dev/null 2>"$tmp/err" || fail "$f: mermaid parse error: $(head -3 "$tmp/err" | tr '\n' ' ')"
  done
  # embedded blocks
  for f in $(grep -l '^```mermaid' -r docs --include='*.md' | sort); do
    awk -v tmp="$tmp" -v fn="$(echo "$f" | tr '/' '_')" '/^```mermaid/{b=1;i++;out=sprintf("%s/%s.%d.mmd",tmp,fn,i);next} /^```/{if(b){b=0;close(out)};next} b{print > out}' "$f"
  done
  for e in "$tmp"/*.md.*.mmd; do
    [[ -f "$e" ]] || continue; n=$((n+1))
    "$MMDC" "${pargs[@]}" -i "$e" -o "$tmp/out.svg" >/dev/null 2>"$tmp/err" || fail "embedded diagram $(basename "$e"): $(head -3 "$tmp/err" | tr '\n' ' ')"
  done
  echo "parsed $n diagrams"
  rm -rf "$tmp"
  fi
fi
rc=0; [[ -s "$FAILS" ]] && rc=1; rm -f "$FAILS"
echo "result: rc=$rc"
exit $rc
