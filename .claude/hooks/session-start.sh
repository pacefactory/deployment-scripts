#!/bin/bash
# SessionStart hook for Claude Code on the web.
#
# Installs the two tools the documentation generators need and that the
# remote container image lacks:
#   - mikefarah yq v4 (build.sh and scripts/docs/*.sh; the Python `yq`
#     wrapper that is on PATH by default silently breaks the profile loop)
#   - mermaid-cli (`mmdc`) for `scripts/docs/check-docs.sh --mermaid`, pointed
#     at the Chromium that Playwright pre-installs in the container.
# Exports PATH, MMDC and MMDC_PUPPETEER_CONFIG for the session through
# $CLAUDE_ENV_FILE. Idempotent; does nothing outside the remote environment.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

YQ_VERSION="${YQ_VERSION:-v4.53.6}"
TOOLS_DIR="${CLAUDE_TOOLS_DIR:-$HOME/.claude-tools}"
mkdir -p "$TOOLS_DIR/bin"

# 1. mikefarah yq
if ! "$TOOLS_DIR/bin/yq" --version 2>/dev/null | grep -q "mikefarah/yq.*${YQ_VERSION}"; then
  arch="$(uname -m)"; case "$arch" in x86_64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; esac
  curl -fsSL -o "$TOOLS_DIR/bin/yq.tmp" \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${arch}"
  chmod +x "$TOOLS_DIR/bin/yq.tmp" && mv "$TOOLS_DIR/bin/yq.tmp" "$TOOLS_DIR/bin/yq"
fi
echo "session-start: $("$TOOLS_DIR/bin/yq" --version)"

# 2. mermaid-cli, using the pre-installed Chromium instead of downloading one
if ! command -v mmdc >/dev/null 2>&1; then
  PUPPETEER_SKIP_DOWNLOAD=1 npm install -g --no-fund --no-audit @mermaid-js/mermaid-cli >/dev/null
fi
chrome="$(find "${PLAYWRIGHT_BROWSERS_PATH:-/opt/pw-browsers}" -maxdepth 3 -type f -name chrome 2>/dev/null | head -1 || true)"
puppeteer_cfg="$TOOLS_DIR/puppeteer.json"
if [ -n "$chrome" ]; then
  printf '{"executablePath":"%s","args":["--no-sandbox"]}\n' "$chrome" > "$puppeteer_cfg"
else
  printf '{"args":["--no-sandbox"]}\n' > "$puppeteer_cfg"
  echo "session-start: WARNING: no pre-installed Chromium found; mmdc will use its own download" >&2
fi
echo "session-start: mmdc $(mmdc --version 2>/dev/null || echo 'not installed')"

# 3. Export for the rest of the session
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export PATH=\"$TOOLS_DIR/bin:\$PATH\""
    echo "export MMDC=\"$(command -v mmdc || echo mmdc)\""
    echo "export MMDC_PUPPETEER_CONFIG=\"$puppeteer_cfg\""
  } >> "$CLAUDE_ENV_FILE"
fi
