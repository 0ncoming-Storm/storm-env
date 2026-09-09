#!/usr/bin/env bash

# ==============================================================================
# Environment Bootstrap Script
# ==============================================================================

set -euo pipefail

# Define storm directories
export STORM_PREFIX="/tmp/${USER}-storm"
export BIN_DIR="${STORM_PREFIX}/bin"
export PATH="${BIN_DIR}:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORM_PKG="${SCRIPT_DIR}/storm-pkg"

echo "=================================================="
echo " Bootstrapping Environment into: ${STORM_PREFIX}"
echo "=================================================="

# Ensure structure exists
mkdir -p "${BIN_DIR}"
mkdir -p "${STORM_PREFIX}/share"
mkdir -p "${STORM_PREFIX}/lib"

# Guarantee storm-pkg is executable
if [[ -f "$STORM_PKG" ]]; then
    chmod +x "$STORM_PKG"
else
    echo "Error: storm-pkg not found in ${SCRIPT_DIR}" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 1. Binary Dependencies Installation (Auto-decompressing)
# ------------------------------------------------------------------------------

echo "--> Installing binaries via storm-pkg..."

# Tree-sitter CLI (.gz archive)
"$STORM_PKG" install tree-sitter \
  "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-x64.gz"

# Neovim AppImage or Tarball (.tar.gz)
"$STORM_PKG" install nvim \
  "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
  "nvim"

# Ripgrep (.tar.gz)
"$STORM_PKG" install rg \
  "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz" \
  "rg"

# FD (.tar.gz)
"$STORM_PKG" install fd \
  "https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz" \
  "fd"


# ------------------------------------------------------------------------------
# 2. Universal Sanity Check and Verification
# ------------------------------------------------------------------------------

echo "--> Verifying installed executables in ${BIN_DIR}..."

for binary in "${BIN_DIR}"/*; do
    if [[ -f "$binary" ]]; then
        bin_name="$(basename "$binary")"
        file_info="$(file -b "$binary")"

        if echo "$file_info" | grep -q "ELF"; then
            echo " [OK] ${bin_name}: Valid ELF executable"
        else
            echo " [WARNING] ${bin_name} is not an ELF executable! (Detected: ${file_info})"
            echo " Attempting emergency decompression..."
            
            # Emergency fallback logic
            if echo "$file_info" | grep -q "gzip"; then
                mv "$binary" "${binary}.gz"
                gunzip "${binary}.gz"
                chmod +x "$binary"
                echo " [FIXED] Decompressed ${bin_name}"
            fi
        fi
    fi
done

# ------------------------------------------------------------------------------
# 3. Environment Exports Setup
# ------------------------------------------------------------------------------

echo "--> Environment environment set up complete."
echo ""
echo "Run the following command or add it to your ~/.bashrc:"
echo "export PATH=\"${BIN_DIR}:\$PATH\""
echo ""
echo "To test Tree-sitter and Neovim immediately:"
echo "  /tmp/${USER}-storm/bin/tree-sitter --version"
echo "  /tmp/${USER}-storm/bin/nvim --headless '+TSUpdateSync' +qa"
