#!/bin/bash

# Install the latest yq binary from GitHub releases to ~/bin/yq

set -euo pipefail

INSTALL_DIR="$HOME/bin"
INSTALL_PATH="$INSTALL_DIR/yq"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  YQ_ARCH="amd64" ;;
  aarch64|arm64) YQ_ARCH="arm64" ;;
  armv7l)  YQ_ARCH="arm" ;;
  i386|i686) YQ_ARCH="386" ;;
  *)
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# Detect OS
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
  linux|darwin) ;;
  *)
    echo "Error: Unsupported OS: $OS"
    exit 1
    ;;
esac

BINARY_NAME="yq_${OS}_${YQ_ARCH}"

# Get latest release download URL
echo "Fetching latest yq release..."
DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/latest/download/${BINARY_NAME}"

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download the binary
echo "Downloading yq (${OS}/${YQ_ARCH}) to ${INSTALL_PATH}..."
if command -v curl &> /dev/null; then
  curl -fsSL "$DOWNLOAD_URL" -o "$INSTALL_PATH"
elif command -v wget &> /dev/null; then
  wget -q "$DOWNLOAD_URL" -O "$INSTALL_PATH"
else
  echo "Error: Neither curl nor wget is available"
  exit 1
fi

# Make it executable
chmod +x "$INSTALL_PATH"

# Verify the installation
if "$INSTALL_PATH" --version &> /dev/null; then
  echo "Successfully installed: $("$INSTALL_PATH" --version)"
else
  echo "Error: yq installation failed"
  exit 1
fi

# Ensure ~/bin is in PATH
add_to_path() {
  local rc_file="$1"
  local path_line='export PATH="$HOME/bin:$PATH"'

  if [ -f "$rc_file" ]; then
    if ! grep -qF '$HOME/bin' "$rc_file" && ! grep -qF '~/bin' "$rc_file"; then
      echo "" >> "$rc_file"
      echo "# Added by installYq.sh" >> "$rc_file"
      echo "$path_line" >> "$rc_file"
      echo "Added ~/bin to PATH in $rc_file"
      return 0
    fi
  fi
  return 1
}

if echo "$PATH" | tr ':' '\n' | grep -qxF "$INSTALL_DIR"; then
  echo "~/bin is already in your PATH"
else
  echo "~/bin is not in your current PATH, updating shell config..."

  UPDATED=0

  # Determine the user's current shell
  CURRENT_SHELL="$(basename "${SHELL:-/bin/bash}")"

  case "$CURRENT_SHELL" in
    zsh)
      if add_to_path "$HOME/.zshrc"; then UPDATED=1; fi
      ;;
    bash)
      # Prefer .bashrc, fall back to .bash_profile
      if add_to_path "$HOME/.bashrc"; then
        UPDATED=1
      elif add_to_path "$HOME/.bash_profile"; then
        UPDATED=1
      fi
      ;;
    *)
      # Try common rc files
      for rc in "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile"; do
        if add_to_path "$rc"; then
          UPDATED=1
          break
        fi
      done
      ;;
  esac

  if [ "$UPDATED" -eq 1 ]; then
    echo "Please restart your shell or run: export PATH=\"\$HOME/bin:\$PATH\""
  else
    echo "Warning: Could not find a shell config file to update."
    echo "Manually add the following to your shell config:"
    echo "  export PATH=\"\$HOME/bin:\$PATH\""
  fi
fi

echo ""
echo "yq has been installed to $INSTALL_PATH"
