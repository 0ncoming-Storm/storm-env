# Storm ZDOTDIR entry point.
#
# storm_bashrc sets ZDOTDIR to this directory right before exec'ing zsh, so
# this file is what zsh reads in place of ~/.zshrc. Its only job is to keep
# the user's own zsh configuration intact and then layer Storm on top.
#
# Global /etc zsh startup files still run as normal; ZDOTDIR only redirects
# the user-level (~) dotfiles, and this shim chains the ones that matter.

# The user's own environment and interactive config, when present.
[[ -f "$HOME/.zshenv" ]] && source "$HOME/.zshenv"
[[ -f "$HOME/.zshrc"  ]] && source "$HOME/.zshrc"

# Locate the Storm repo. STORM_REPO is exported by storm_bashrc; fall back to
# ZDOTDIR's parent, then the default clone location.
if [[ -z "$STORM_REPO" ]]; then
  if [[ -n "$ZDOTDIR" ]]; then
    STORM_REPO="${ZDOTDIR:h}"
  else
    STORM_REPO="$HOME/.storm-env"
  fi
fi

# Load Storm's zsh configuration (idempotent -- safe if ~/.zshrc already
# sourced it).
[[ -f "$STORM_REPO/storm_zshrc" ]] && source "$STORM_REPO/storm_zshrc"
