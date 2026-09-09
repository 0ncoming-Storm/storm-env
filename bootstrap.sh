#!/bin/bash
# bootstrap.sh - Storm Package Manager (Fixed Extraction Logic)

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
    
    if command -v "$name" >/dev/null 2>&1 || [ -f "$BIN_DIR/$name" ]; then
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
        # Extract into a temp directory to cleanly locate and move the binary
        local tmp_extract="/tmp/storm-extract-$name"
        mkdir -p "$tmp_extract"
        curl -sL "$url" | tar -xzf - -C "$tmp_extract" 2>/dev/null
        
        # Find the target binary inside the extracted files and move it directly into BIN_DIR
        find "$tmp_extract" -type f -name "$name" -exec mv {} "$BIN_DIR/" \; 2>/dev/null
        rm -rf "$tmp_extract"
    elif [[ "$url" == *.zip ]]; then
        local tmp_zip="/tmp/$USER-storm-$name.zip"
        curl -sL "$url" -o "$tmp_zip"
        unzip -q -j "$tmp_zip" "*$name*" -d "$BIN_DIR" 2>/dev/null
        rm -f "$tmp_zip"
    else
        curl -sL "$url" -o "$BIN_DIR/$name"
    fi

    chmod +x "$BIN_DIR/$name" 2>/dev/null
}

echo "=== Storm Package Sync ==="

# ==============================================================================
# MANIFEST (Fixed patterns)
# ==============================================================================
# Neovim
install_github_bin "nvim" "neovim/neovim" "nvim-linux-x86_64.tar.gz"

# Ripgrep
install_github_bin "rg" "BurntSushi/ripgrep" "x86_64-unknown-linux-musl.tar.gz"

# Lazygit (Fixed: lower-case linux_x86_64)
install_github_bin "lazygit" "jesseduffield/lazygit" "Linux_x86_64|linux_x86_64"

# fzf
install_github_bin "fzf" "junegunn/fzf" "linux_amd64.tar.gz"

# eza
install_github_bin "eza" "eza-community/eza" "x86_64-unknown-linux-gnu.tar.gz"

# jq
install_github_bin "jq" "jqlang/jq" "jq-linux-x86_64"

echo "=== Sync Complete ==="
