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
        # Search recursively for the binary inside extracted subfolders
        local bin_path
        bin_path=$(find "$tmp_extract" -type f -name "$name" | head -n 1)
        if [ -n "$bin_path" ]; then
            mv "$bin_path" "$BIN_DIR/$name"
        fi
#!/bin/bash
# bootstrap.sh - Storm Package Manager Installer

STORM="/tmp/$USER-storm"
BIN_DIR="$STORM/bin"
STORM_REPO="$HOME/.storm-env"
MANIFEST="$STORM_REPO/packages.tsv"

mkdir -p "$BIN_DIR" "$STORM/share" "$STORM/state" "$STORM/cache" "$HOME/.config"

# Link Neovim configuration into persistent HOME
if [ -d "$STORM_REPO/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    rm -rf "$HOME/.config/nvim"
    ln -sf "$STORM_REPO/nvim" "$HOME/.config/nvim"
fi

get_download_url() {
    local repo="$1"
    local pattern="$2"
    local url=""
    local api_header=""

    # Optional: export GITHUB_TOKEN="your_token" in .bashrc to skip limits
    if [ -n "$GITHUB_TOKEN" ]; then
        api_header="-H \"Authorization: token $GITHUB_TOKEN\""
    fi

    # 1. Try API first
    local api_cmd="curl -s $api_header https://api.github.com/repos/$repo/releases/latest"
    url=$(eval "$api_cmd" | grep "browser_download_url" | grep -E "$pattern" | cut -d '"' -f 4 | head -n 1)

    # 2. Fallback to HTML scraping if API is rate-limited (url is empty)
    if [ -z "$url" ]; then
        url=$(curl -sL "https://github.com/$repo/releases/latest" | grep -oE "href=\"/[^\"]+/releases/download/[^\"]+\"" | grep -E "$pattern" | cut -d '"' -f 2 | head -n 1)
        if [ -n "$url" ]; then
            url="https://github.com$url"
        fi
    fi
    echo "$url"
}

install_github_bin() {
    local name="$1"
    local repo="$2"
    local pattern="$3"
    
    if [ -f "$BIN_DIR/$name" ]; then
        echo " [✓] $name is installed"
        return
    fi

    echo " [↓] Installing $name from $repo..."
    local url
    url=$(get_download_url "$repo" "$pattern")

    if [ -z "$url" ]; then
        echo " [X] Failed to fetch URL for $name (Rate limited?)"
        return
    fi

    if [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
        local tmp_extract="/tmp/storm-extract-$name"
        mkdir -p "$tmp_extract"
        curl -sL "$url" | tar -xzf - -C "$tmp_extract" 2>/dev/null
        local bin_path=$(find "$tmp_extract" -type f -name "$name" | head -n 1)
        if [ -n "$bin_path" ]; then
            mv "$bin_path" "$BIN_DIR/$name"
        fi
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

install_neovim() {
    if [ -f "$BIN_DIR/nvim" ]; then
        echo " [✓] nvim is installed"
        return
    fi
    echo " [↓] Installing Neovim..."
    local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    mkdir -p "$STORM/nvim-app"
    curl -sL "$url" | tar -xzf - -C "$STORM/nvim-app" --strip-components=1
    ln -sf "$STORM/nvim-app/bin/nvim" "$BIN_DIR/nvim"
}

echo "=== Storm Package Sync ==="

install_neovim

# Read and install from TSV Manifest
if [ -f "$MANIFEST" ]; then
    while IFS=$'\t' read -r name repo pattern; do
        # Skip empty lines
        [ -z "$name" ] && continue
        install_github_bin "$name" "$repo" "$pattern"
    done < "$MANIFEST"
fi

# Tree-Sitter CLI compatibility handling
if command -v npm >/dev/null 2>&1 && ! [ -f "$BIN_DIR/tree-sitter" ]; then
    npm install -g --prefix "$STORM" tree-sitter-cli >/dev/null 2>&1 || true
elif command -v cargo >/dev/null 2>&1 && ! [ -f "$BIN_DIR/tree-sitter" ]; then
    cargo install tree-sitter-cli --root "$STORM" >/dev/null 2>&1 || true
fi

echo " [⚙] Syncing Neovim parsers..."
if [ -f "$BIN_DIR/nvim" ]; then
    # Must export paths so headless nvim knows where to put plugins during install
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$STORM/share"
    export XDG_STATE_HOME="$STORM/state"
    export XDG_CACHE_HOME="$STORM/cache"
    export PATH="$BIN_DIR:$PATH"
    "$BIN_DIR/nvim" --headless "+Lazy! sync" "+TSUpdateSync" +qa >/dev/null 2>&1 || true
fi

echo "=== Sync Complete ==="
