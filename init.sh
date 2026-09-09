#!/bin/bash
# init.sh - Storm Environment setup (minimal alternative to storm_bashrc)

: "${STORM_REPO:=$HOME/.storm-env}"
export STORM_REPO

export STORM="/tmp/$USER-storm"

# Prepend without duplicating -- this file may be sourced more than once.
case ":$PATH:" in
  *":$STORM/bin:"*) ;;
  *) export PATH="$STORM/bin:$STORM_REPO:$PATH" ;;
esac

# Persist configs in HOME, but push heavy data/plugins/cache to /tmp
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$STORM/share"
export XDG_STATE_HOME="$STORM/state"
export XDG_CACHE_HOME="$STORM/cache"

# Automatic Recovery
if [ ! -d "$STORM/bin" ]; then
  echo -e "\033[1;33m[Storm] Missing /tmp binaries. Rebuilding...\033[0m"
  mkdir -p "$STORM"
  bash "$STORM_REPO/bootstrap.sh"
fi

# Tool Aliases -- only for binaries that actually exist
command -v nvim    >/dev/null 2>&1 && alias vim="nvim"
command -v eza     >/dev/null 2>&1 && alias ls="eza"
command -v lazygit >/dev/null 2>&1 && alias lg="lazygit"

storm-update() {
  echo "Updating Storm repository..."
  cd "$STORM_REPO" || return
  git pull
  bash "$STORM_REPO/bootstrap.sh"
  cd - >/dev/null || return
}

storm-rebuild() {
  echo "Wiping and rebuilding Storm binaries in /tmp..."
  rm -rf "$STORM"
  bash "$STORM_REPO/bootstrap.sh"
}

# Auto-start Tmux on SSH -- interactive shells only, or scp/sftp/rsync break
case "$-" in
  *i*)
    if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ] && [ "$TERM" != "dumb" ]; then
      command -v tmux >/dev/null 2>&1 && exec tmux new-session -A -s main
    fi
    ;;
esac
