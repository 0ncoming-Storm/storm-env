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

# Special Installer for Neovim (Preserves runtime files)
install_neovim() {
    if [ -f "$BIN_DIR/nvim" ]; then
        echo " [✓] nvim is installed"
        return
    fi

    echo " [↓] Installing Neovim..."
    local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    
    mkdir -p "$STORM/nvim-app"
    curl -sL "$url" | tar -xzf - -C "$STORM/nvim-app" --strip-components=1
    
    # Symlink binary into execution PATH
    ln -sf "$STORM/nvim-app/bin/nvim" "$BIN_DIR/nvim"
}

# Generic Installer for single-binary utilities
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
        local tmp_extract="/tmp/storm-extract-$name"
        mkdir -p "$tmp_extract"
        curl -sL "$url" | tar -xzf - -C "$tmp_extract" 2>/dev/null
        find "$tmp_extract" -type f -name "$name" -exec mv {} "$BIN_DIR/" \; 2>/dev/null
        rm -rf "$tmp_extract"
    elif [[ "$url" == *.gz ]]; then
        # Direct decompression for single gzip files like tree-sitter
        curl -sL "$url" | gunzip > "$BIN_DIR/$name"
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

# 1. Neovim (Full Runtime Installation)
install_neovim

# 2. CLI Utilities & Tree-Sitter
install_github_bin "tree-sitter" "tree-sitter/tree-sitter" "tree-sitter-linux-x64.gz"
install_github_bin "tmux" "nolanopt/tmux-builds" "tmux-.*-x86_64"
install_github_bin "rg" "BurntSushi/ripgrep" "x86_64-unknown-linux-musl.tar.gz"
install_github_bin "lazygit" "jesseduffield/lazygit" "Linux_x86_64|linux_x86_64"
install_github_bin "fzf" "junegunn/fzf" "linux_amd64.tar.gz"
install_github_bin "eza" "eza-community/eza" "x86_64-unknown-linux-gnu.tar.gz"
install_github_bin "jq" "jqlang/jq" "jq-linux-x86_64"

# 3. Neovim Automated Headless Configuration & Sync
echo " [⚙] Pre-configuring Neovim plugins & Tree-sitter parsers..."
export XDG_CONFIG_HOME="$STORM/config"
export XDG_DATA_HOME="$STORM/share"
export XDG_STATE_HOME="$STORM/state"
export XDG_CACHE_HOME="$STORM/cache"
export PATH="$BIN_DIR:$PATH"

if [ -f "$BIN_DIR/nvim" ]; then
    # Headless sync (installs plugins via Lazy/Packer and updates Treesitter)
    "$BIN_DIR/nvim" --headless "+Lazy! sync" "+TSUpdateSync" +qa >/dev/null 2>&1 || \
    "$BIN_DIR/nvim" --headless "+PackerSync" +qa >/dev/null 2>&1 || true
    echo " [✓] Neovim configuration synced."
fi

echo "=== Sync Complete ==="
