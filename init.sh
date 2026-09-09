#!/bin/bash
# init.sh - Storm Environment setup

export STORM="/tmp/$USER-storm"
export PATH="$STORM/bin:$STORM_REPO:$PATH"

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

# Tool Aliases
alias vim="nvim"
alias ls="eza"
alias lg="lazygit"

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

# Auto-start Tmux on SSH
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ] && command -v tmux >/dev/null 2>&1; then
  exec tmux new-session -A -s main
fi
