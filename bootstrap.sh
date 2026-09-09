#!/bin/bash
# bootstrap.sh - Storm Package Manager Installer (With Logging)

STORM="/tmp/$USER-storm"
BIN_DIR="$STORM/bin"
STORM_REPO="$HOME/.storm-env"
MANIFEST="$STORM_REPO/packages.tsv"
LOG_FILE="$STORM/bootstrap.log"

mkdir -p "$BIN_DIR" "$STORM/share" "$STORM/state" "$STORM/cache" "$HOME/.config"

# Redirect stdout and stderr to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo " Storm Sync Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

# Link Neovim configuration into persistent HOME
if [ -d "$STORM_REPO/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    rm -rf "$HOME/.config/nvim"
    ln -sf "$STORM_REPO/nvim" "$HOME/.config/nvim"
fi

get_download_url() {
    local repo="$1"
    local pattern="$2"
    local url=""
    local api_header=()

    if [ -n "$GITHUB_TOKEN" ]; then
        api_header=(-H "Authorization: token $GITHUB_TOKEN")
    fi

    # 1. Try GitHub API
    local api_response
    api_response=$(curl -s "${api_header[@]}" "https://api.github.com/repos/$repo/releases/latest")

    if echo "$api_response" | grep -q '"message":'; then
        local msg
        msg=$(echo "$api_response" | grep '"message"' | cut -d '"' -f 4)
        echo "     [!] API Warning: $msg" >&2
    else
        url=$(echo "$api_response" | grep "browser_download_url" | grep -E "$pattern" | cut -d '"' -f 4 | head -n 1)
        [ -n "$url" ] && echo "     [i] URL resolved via GitHub API" >&2
    fi

    # 2. Fallback to Web Scraping if API failed/rate-limited
    if [ -z "$url" ]; then
        echo "     [i] Attempting HTML web scrape fallback..." >&2
        local html_content
        html_content=$(curl -sL "https://github.com/$repo/releases/latest")
        
        local scraped_path
        scraped_path=$(echo "$html_content" | grep -oE '/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+/releases/download/[^"]+' | grep -E "$pattern" | head -n 1)
        
        if [ -n "$scraped_path" ]; then
            url="https://github.com$scraped_path"
            echo "     [i] URL resolved via HTML web scrape" >&2
        else
            echo "     [X] Web scrape failed to match pattern '$pattern'" >&2
        fi
    fi

    echo "$url"
}

install_github_bin() {
    local name="$1"
    local repo="$2"
    local pattern="$3"
    
    if [ -f "$BIN_DIR/$name" ]; then
        echo " [✓] $name is already installed"
        return
    fi

    echo " [↓] Processing $name ($repo)..."
    local url
    url=$(get_download_url "$repo" "$pattern")

    if [ -z "$url" ]; then
        echo " [X] Failed to fetch download URL for $name"
        return
    fi

    echo "     Target: $url"

    if [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
        local tmp_extract="/tmp/storm-extract-$name"
        mkdir -p "$tmp_extract"
        if curl -sL "$url" | tar -xzf - -C "$tmp_extract" 2>/dev/null; then
            local bin_path
            bin_path=$(find "$tmp_extract" -type f -name "$name" | head -n 1)
            if [ -n "$bin_path" ]; then
                mv "$bin_path" "$BIN_DIR/$name"
                echo " [✓] Successfully installed $name"
            else
                echo " [X] Extraction failed: '$name' executable not found in archive"
            fi
        else
            echo " [X] Download/Tar extraction error"
        fi
        rm -rf "$tmp_extract"
    elif [[ "$url" == *.zip ]]; then
        local tmp_zip="/tmp/$USER-storm-$name.zip"
        curl -sL "$url" -o "$tmp_zip"
        if unzip -q -j "$tmp_zip" "*$name*" -d "$BIN_DIR" 2>/dev/null; then
            echo " [✓] Successfully installed $name"
        else
            echo " [X] Zip extraction error"
        fi
        rm -f "$tmp_zip"
    else
        if curl -sL "$url" -o "$BIN_DIR/$name"; then
            echo " [✓] Successfully installed $name"
        else
            echo " [X] Binary download error"
        fi
    fi

    chmod +x "$BIN_DIR/$name" 2>/dev/null
}

install_neovim() {
    if [ -f "$BIN_DIR/nvim" ]; then
        echo " [✓] nvim is already installed"
        return
    fi
    echo " [↓] Installing Neovim..."
    local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    echo "     Target: $url"
    mkdir -p "$STORM/nvim-app"
    if curl -sL "$url" | tar -xzf - -C "$STORM/nvim-app" --strip-components=1; then
        ln -sf "$STORM/nvim-app/bin/nvim" "$BIN_DIR/nvim"
        echo " [✓] Successfully installed Neovim"
    else
        echo " [X] Neovim installation failed"
    fi
}

install_neovim

if [ -f "$MANIFEST" ]; then
    while IFS=$'\t' read -r name repo pattern; do
        [ -z "$name" ] && continue
        install_github_bin "$name" "$repo" "$pattern"
    done < "$MANIFEST"
else
    echo " [!] Manifest file missing: $MANIFEST"
fi

if command -v npm >/dev/null 2>&1 && ! [ -f "$BIN_DIR/tree-sitter" ]; then
    echo " [↓] Installing tree-sitter CLI via npm..."
    npm install -g --prefix "$STORM" tree-sitter-cli >/dev/null 2>&1 || true
elif command -v cargo >/dev/null 2>&1 && ! [ -f "$BIN_DIR/tree-sitter" ]; then
    echo " [↓] Installing tree-sitter CLI via cargo..."
    cargo install tree-sitter-cli --root "$STORM" >/dev/null 2>&1 || true
fi

echo " [⚙] Pre-configuring Neovim plugins & treesitter..."
if [ -f "$BIN_DIR/nvim" ]; then
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$STORM/share"
    export XDG_STATE_HOME="$STORM/state"
    export XDG_CACHE_HOME="$STORM/cache"
    export PATH="$BIN_DIR:$PATH"
    "$BIN_DIR/nvim" --headless "+Lazy! sync" "+TSUpdateSync" +qa >/dev/null 2>&1 || true
    echo " [✓] Neovim synced"
fi

echo "=== Sync Complete ==="
echo " Log written to: $LOG_FILE"
