#!/usr/bin/env bash

set -euo pipefail

export STORM_PREFIX="/tmp/${USER}-storm"
export BIN_DIR="${STORM_PREFIX}/bin"
export PATH="${BIN_DIR}:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORM_PKG="${SCRIPT_DIR}/storm-pkg"

echo "=================================================="
echo " Bootstrapping Environment into: ${STORM_PREFIX}"
echo "=================================================="

mkdir -p "${BIN_DIR}" "${STORM_PREFIX}/share" "${STORM_PREFIX}/lib"

if [[ -f "$STORM_PKG" ]]; then
    chmod +x "$STORM_PKG"
else
    echo "Error: storm-pkg not found in ${SCRIPT_DIR}" >&2
    exit 1
fi

echo "--> Installing core binaries via storm-pkg..."

"$STORM_PKG" install tree-sitter \
  "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-x64.gz"

"$STORM_PKG" install nvim \
  "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" \
  "nvim"

"$STORM_PKG" install rg \
  "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz" \
  "rg"

"$STORM_PKG" install fd \
  "https://github.com/sharkdp/fd/releases/download/v10.1.0/fd-v10.1.0-x86_64-unknown-linux-musl.tar.gz" \
  "fd"

# ------------------------------------------------------------------------------
# AUTOMATION 1: Inject PATH directly into ~/.bashrc
# ------------------------------------------------------------------------------
BASHRC="${HOME}/.bashrc"
PATH_LINE="export PATH=\"${BIN_DIR}:\$PATH\""

if [[ -f "$BASHRC" ]]; then
    if ! grep -qs "${BIN_DIR}" "$BASHRC"; then
        echo "--> Injecting STORM PATH into ${BASHRC}..."
        echo "" >> "$BASHRC"
        echo "# Storm Environment Path" >> "$BASHRC"
        echo "$PATH_LINE" >> "$BASHRC"
        echo "✔ Added to ${BASHRC}"
    fi
fi

# ------------------------------------------------------------------------------
# AUTOMATION 2: Run Neovim Treesitter setup automatically
# ------------------------------------------------------------------------------
echo "--> Syncing Neovim and Treesitter parsers..."
if command -v nvim >/dev/null 2>&1; then
    nvim --headless "+Lazy! sync" "+TSUpdateSync" +qa || true
    echo "✔ Neovim Treesitter parsers updated."
fi

echo "=================================================="
echo " Bootstrap complete! Run 'source ~/.bashrc' or open a new terminal."
echo "=================================================="
