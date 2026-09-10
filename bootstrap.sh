#!/bin/bash
# bootstrap.sh - Storm Package Manager Installer (With Logging & Fallbacks)

STORM="/var/tmp/$USER-storm"
BIN_DIR="$STORM/bin"
STORM_REPO="$HOME/.storm-env"
MANIFEST="$STORM_REPO/packages.tsv"
LOG_FILE="$STORM/bootstrap.log"

mkdir -p "$BIN_DIR" "$STORM/share" "$STORM/state" "$STORM/cache" "$HOME/.config"

# Rotate the previous run's log. Appending forever grew this file without bound
# across every shell startup that triggered an auto-rebuild.
[ -f "$LOG_FILE" ] && mv -f "$LOG_FILE" "$LOG_FILE.old"

# Redirect stdout and stderr to both terminal and log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=================================================="
echo " Storm Sync Started: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================="

# Link Neovim configuration into persistent HOME.
# A dangling symlink still passes [ -L ], so testing only for -L would leave a
# broken link in place forever. And a real pre-existing ~/.config/nvim is backed
# up, never rm -rf'd.
if [ -d "$STORM_REPO/nvim" ]; then
    nvim_link="$HOME/.config/nvim"
    if [ -L "$nvim_link" ] && [ "$(readlink "$nvim_link")" = "$STORM_REPO/nvim" ]; then
        : # already linked correctly
    elif [ -L "$nvim_link" ]; then
        echo " [!] Repointing stale nvim symlink ($(readlink "$nvim_link"))"
        ln -sfn "$STORM_REPO/nvim" "$nvim_link"
    elif [ -e "$nvim_link" ]; then
        backup="$nvim_link.storm-backup-$(date +%Y%m%d%H%M%S)"
        echo " [!] Existing Neovim config found -- moved to $backup"
        mv "$nvim_link" "$backup"
        ln -sfn "$STORM_REPO/nvim" "$nvim_link"
    else
        ln -sfn "$STORM_REPO/nvim" "$nvim_link"
    fi
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

    # 2. Fallback to Robust Web Scraping
    if [ -z "$url" ]; then
        echo "     [i] Attempting HTML web scrape fallback..." >&2
        
        local html_content
        html_content=$(curl -sL "https://github.com/$repo/releases/latest")
        
        local scraped_path
        scraped_path=$(echo "$html_content" | grep -oE '"/[^"]+/releases/download/[^"]+"' | tr -d '"' | grep -E "$pattern" | head -n 1)

        # Fallback for hidden/expanded asset lists
        if [ -z "$scraped_path" ]; then
            local tag
            tag=$(echo "$html_content" | grep -oE '/releases/tag/[^"]+' | head -n 1 | cut -d'/' -f 5)
            if [ -n "$tag" ]; then
                local expanded_html
                expanded_html=$(curl -sL "https://github.com/$repo/releases/expanded_assets/$tag")
                scraped_path=$(echo "$expanded_html" | grep -oE '"/[^"]+/releases/download/[^"]+"' | tr -d '"' | grep -E "$pattern" | head -n 1)
            fi
        fi

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

    # Only trust an existing binary if it is a real, non-empty executable.
    # A previous failed run could have left a truncated or HTML-error file here,
    # which would otherwise be skipped forever as "already installed".
    if [ -s "$BIN_DIR/$name" ] && [ -x "$BIN_DIR/$name" ]; then
        echo " [✓] $name is already installed"
        return
    elif [ -e "$BIN_DIR/$name" ]; then
        echo " [!] $name exists but is empty or not executable -- reinstalling"
        rm -f "$BIN_DIR/$name"
    fi

    echo " [↓] Processing $name ($repo)..."
    local url
    url=$(get_download_url "$repo" "$pattern")

    if [ -z "$url" ]; then
        echo " [X] Failed to fetch download URL for $name"
        return
    fi

    echo "     Target: $url"

    # NOTE: curl MUST use -f/--fail. Without it a 404 or a rate-limit page exits
    # 0 and its error body gets written to disk as if it were the binary.
    if [[ "$url" == *.tar.gz ]] || [[ "$url" == *.tgz ]]; then
        local tmp_extract="/var/tmp/storm-extract-$name"
        rm -rf "$tmp_extract"
        mkdir -p "$tmp_extract"
        if curl -fsSL "$url" | tar -xzf - -C "$tmp_extract" 2>/dev/null; then
            local bin_path
            bin_path=$(find "$tmp_extract" -type f -name "$name" | head -n 1)
            if [ -n "$bin_path" ]; then
                mv "$bin_path" "$BIN_DIR/$name"
                echo " [✓] Successfully installed $name"
            else
                echo " [X] Extraction failed: '$name' executable not found in archive"
            fi
        else
            echo " [X] Download/Tar extraction error (HTTP failure or corrupt archive)"
        fi
        rm -rf "$tmp_extract"
    elif [[ "$url" == *.zip ]]; then
        local tmp_zip="/var/tmp/$USER-storm-$name.zip"
        if curl -fsSL "$url" -o "$tmp_zip" && unzip -q -j "$tmp_zip" "$name" -d "$BIN_DIR" 2>/dev/null; then
            echo " [✓] Successfully installed $name"
        else
            echo " [X] Zip extraction error"
            rm -f "$BIN_DIR/$name"
        fi
        rm -f "$tmp_zip"
    else
        # Raw binary (e.g. jq). Download to a temp file and validate before
        # promoting it, so a failed fetch never leaves a bogus executable.
        local tmp_bin="$BIN_DIR/.$name.part"
        if curl -fsSL "$url" -o "$tmp_bin" && [ -s "$tmp_bin" ]; then
            mv "$tmp_bin" "$BIN_DIR/$name"
            echo " [✓] Successfully installed $name"
        else
            echo " [X] Binary download error (HTTP failure or empty response)"
            rm -f "$tmp_bin"
        fi
    fi

    [ -f "$BIN_DIR/$name" ] && chmod +x "$BIN_DIR/$name"
}

install_neovim() {
    if [ -x "$BIN_DIR/nvim" ] && [ -e "$STORM/nvim-app/bin/nvim" ]; then
        echo " [✓] nvim is already installed"
        return
    fi
    echo " [↓] Installing Neovim..."
    local url="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    echo "     Target: $url"
    # Wipe first: --strip-components=1 into a populated dir mixes two versions.
    rm -rf "$STORM/nvim-app"
    mkdir -p "$STORM/nvim-app"
    if curl -fsSL "$url" | tar -xzf - -C "$STORM/nvim-app" --strip-components=1 && [ -x "$STORM/nvim-app/bin/nvim" ]; then
        ln -sfn "$STORM/nvim-app/bin/nvim" "$BIN_DIR/nvim"
        echo " [✓] Successfully installed Neovim"
    else
        echo " [X] Neovim installation failed"
        rm -rf "$STORM/nvim-app"
        rm -f "$BIN_DIR/nvim"
    fi
}

echo "=== Storm Package Sync ==="

install_neovim

if [ -f "$MANIFEST" ]; then
    # `|| [ -n "$name" ]` keeps the final row when the file has no trailing
    # newline -- without it the last package is silently skipped.
    while IFS=$'\t' read -r name repo pattern || [ -n "$name" ]; do
        [ -z "$name" ] && continue
        case "$name" in \#*) continue ;; esac   # allow commented-out rows
        install_github_bin "$name" "$repo" "$pattern"
    done < "$MANIFEST"
else
    echo " [!] Manifest file missing: $MANIFEST"
fi

echo " [⚙] Pre-configuring Neovim plugins..."
if [ -f "$BIN_DIR/nvim" ]; then
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$STORM/share"
    export XDG_STATE_HOME="$STORM/state"
    export XDG_CACHE_HOME="$STORM/cache"
    export PATH="$BIN_DIR:$PATH"
    # No +TSUpdateSync: nvim/lua/plugins/no-treesitter.lua disables
    # nvim-treesitter, so the tree-sitter CLI and parser sync are gone too.
    "$BIN_DIR/nvim" --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true
    echo " [✓] Neovim synced"
fi

echo "=== Sync Complete ==="
