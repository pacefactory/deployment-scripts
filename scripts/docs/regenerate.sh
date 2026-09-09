#!/bin/bash
# regenerate.sh [--check]
# Regenerates every derived documentation file in docs/ from the fragments,
# build.sh, the reference deployment inputs and the data files in scripts/docs/.
# With --check, rebuilds the reference deployments in check mode (exit 1 on
# drift) and then regenerates the pages so 'git diff --exit-code docs' can be
# used as the drift test.
set -euo pipefail
cd "$(dirname "$0")/../.."
if [[ "${1:-}" == "--check" ]]; then ./scripts/docs/build-reference-deployment.sh --all --check; else ./scripts/docs/build-reference-deployment.sh --all; fi
./scripts/docs/render-glossary.sh
./scripts/docs/render-profile-page.sh --all
./scripts/docs/render-profile-catalog.sh
./scripts/docs/render-env-reference.sh
./scripts/docs/render-deployment-page.sh --all
./scripts/docs/render-docs-index.sh
echo "regeneration complete"
