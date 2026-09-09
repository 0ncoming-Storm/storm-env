#!/bin/bash
# bootstrap.sh - Storm Package Manager

STORM="/tmp/$USER-storm"
BIN_DIR="$STORM/bin"

mkdir -p "$BIN_DIR" "$STORM/config" "$STORM/share" "$STORM/state" "$STORM/cache"

# Link Neovim configuration from repo
if [ -d "$STORM/repo/nvim" ]; then
    rm -rf "$STORM/config/nvim"
    ln -sf "$STORM/repo/nvim" "$STORM/config/nvim"
fi

# Generic installer function for GitHub releases
install_github_bin() {
    local name="$1"
    local repo="$2"
    local pattern="$3"
    
    if command -v "$name" >/dev/null 2>&1; then
        echo " [✓] $name is installed"
        return
    fi

    echo " [↓] Installing $name from $repo..."
    local url
    url=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | \
          grep "browser_download_url" | grep -E "$pattern" | cut -d '"' -f 4 | head -n 1)

    if [ -z "$url" ]; then
        echo " [X] Failed to fetch URL for $name"
        return
    fi

    if [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
        curl -sL "$url" | tar -xzf - -C "$BIN_DIR" --wildcards "*$name*" --strip-components=1 2>/dev/null || \
        curl -sL "$url" | tar -xzf - -C "$BIN_DIR" "$name" 2>/dev/null
    elif [[ "$url" == *.zip ]]; then
        local tmp_zip="/tmp/$USER-storm-$name.zip"
        curl -sL "$url" -o "$tmp_zip"
        unzip -q -j "$tmp_zip" "*$name*" -d "$BIN_DIR"
        rm -f "$tmp_zip"
    else
        curl -sL "$url" -o "$BIN_DIR/$name"
    fi

    chmod +x "$BIN_DIR/$name" 2>/dev/null
}

echo "=== Storm Package Sync ==="

# ==============================================================================
# MANIFEST: Add any tools you want here
# ==============================================================================
# Neovim
install_github_bin "nvim" "neovim/neovim" "nvim-linux-x86_64.tar.gz"

# Ripgrep (Grep replacement, required for LazyVim Telescope)
install_github_bin "rg" "BurntSushi/ripgrep" "x86_64-unknown-linux-musl.tar.gz"

# Lazygit (Terminal Git GUI)
install_github_bin "lazygit" "jesseduffield/lazygit" "Linux_x86_64.tar.gz"

# fzf (Fuzzy finder)
install_github_bin "fzf" "junegunn/fzf" "linux_amd64.tar.gz"

# eza (Modern ls replacement)
install_github_bin "eza" "eza-community/eza" "x86_64-unknown-linux-gnu.tar.gz"

# jq (JSON processor)
install_github_bin "jq" "jqlang/jq" "jq-linux-x86_64"

echo "=== Sync Complete ==="
