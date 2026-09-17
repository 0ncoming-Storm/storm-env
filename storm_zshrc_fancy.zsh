# storm_zshrc_fancy.zsh - Storm's optional plugin layer (phase 2)
#
# Sourced from storm_zshrc ONLY when STORM_FANCY is set. It layers the zinit
# plugin suite on top of the core shell:
#   * powerlevel10k          -- the fancy prompt (takes over from the core one)
#   * zsh-completions        -- ~2000 extra completion definitions
#   * fzf-tab                -- fzf as the completion menu
#   * fast-syntax-highlighting   (turbo: after first prompt)
#   * zsh-autosuggestions          (turbo: after first prompt)
#   * zsh-history-substring-search (turbo: after first prompt)
#   * fastfetch              -- daily system-info splash
#
# Everything here is best-effort: if any piece fails, the core shell
# (prompt, line editing, completion, aliases) keeps working. zinit
# bootstraps itself into /var/tmp the first time it is needed, so a wiped
# /var/tmp heals itself on the next shell.

[[ -n $__STORM_FANCY_LOADED ]] && return 0
typeset -g __STORM_FANCY_LOADED=1

autoload -Uz is-at-least add-zsh-hook
if is-at-least 5.7.1 && (( $+commands[git] )); then
  typeset -gA ZINIT
  ZINIT[HOME_DIR]="$XDG_DATA_HOME/zinit"

  # Self-bootstrap zinit. A partially failed clone is wiped and retried,
  # otherwise git refuses to clone into the non-empty directory forever.
  if [[ ! -f $ZINIT[HOME_DIR]/zinit.git/zinit.zsh ]]; then
    command rm -rf "$ZINIT[HOME_DIR]/zinit.git"
    command mkdir -p "$ZINIT[HOME_DIR]"
    command git clone --quiet --depth 1 \
      https://github.com/zdharma-continuum/zinit \
      "$ZINIT[HOME_DIR]/zinit.git" 2>/dev/null
  fi
  [[ -f $ZINIT[HOME_DIR]/zinit.git/zinit.zsh ]] && source "$ZINIT[HOME_DIR]/zinit.git/zinit.zsh"

  if (( $+functions[zinit] )); then
    # Load order is load-bearing:
    #   1. zsh-completions appends ~2000 completion definitions to FPATH
    #   2. compinit rebuilds the completion system with them (the core file
    #      already ran a plain compinit, so completion works from the first
    #      prompt even before this finishes)
    #   3. fzf-tab hooks the completion menu -- must be AFTER compinit,
    #      but BEFORE anything that wraps widgets (autosuggestions, f-sy-h)
    #   4. powerlevel10k takes over the prompt
    # The widget-wrapping plugins are deferred to turbo mode (after the
    # first prompt paints) further down.
    zinit ice depth=1 lucid
    zinit light zsh-users/zsh-completions

    autoload -Uz compinit
    compinit -u -d "$XDG_CACHE_HOME/zsh/zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

    zinit ice depth=1 lucid
    zinit light Aloxaf/fzf-tab

    # fzf-tab: per-context previews (dir listings for cd, file previews for
    # editors, process info for kill). Each preview command degrades
    # gracefully when eza/bat are missing.
    zstyle ':fzf-tab:complete:cd:*' fzf-preview \
      '[[ -d $realpath ]] && { eza -1 --color=always --group-directories-first $realpath 2>/dev/null || ls -1 $realpath }'
    zstyle ':fzf-tab:complete:(nvim|vim|n|less|bat|view|more):*' fzf-preview \
      'bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null || head -n 100 $realpath 2>/dev/null'
    zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' fzf-preview \
      'echo ${(P)word}'
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
      '[[ $group == "process ID" ]] && ps -p $word -o command= 2>/dev/null'
    zstyle ':fzf-tab:complete:systemctl-*:argument-rest' fzf-preview \
      'systemctl status $word 2>/dev/null | head -n 20'

    zinit ice depth=1 lucid
    zinit light romkatv/powerlevel10k
    if (( $+functions[p10k] )) && [[ -f $STORM_REPO/p10k.zsh ]]; then
      source "$STORM_REPO/p10k.zsh"
      # p10k now owns the prompt: its precmd hook is registered after the
      # core prompt's, so it repaints after any interference. Drop the core
      # prompt's hook -- leaving it in would fight p10k over $PROMPT.
      add-zsh-hook -d precmd _storm_apply_prompt
    else
      print -P "%F{yellow}[Storm] powerlevel10k did not load -- keeping the core prompt. Reopen the shell, or run storm-rebuild if it persists.%f"
    fi

    # zsh-autosuggestions: grey-on-right suggestions from history+completion.
    typeset -g ZSH_AUTOSUGGEST_STRATEGY=(history completion)
    typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'

    # Turbo mode: everything below loads right after the first prompt is
    # painted, so it costs ~0 ms of startup latency.
    zinit wait lucid for \
      zdharma-continuum/fast-syntax-highlighting \
      atload'!_zsh_autosuggest_start' \
        zsh-users/zsh-autosuggestions \
      atload'!_storm_bind_hss' \
        zsh-users/zsh-history-substring-search
  fi
fi

# Defined here (not in atload) so it exists before turbo plugins fire.
# Binds history-substring-search: type a fragment, then Up/Down cycle
# through history entries containing it.
_storm_bind_hss() {
  typeset -g HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='bg=default,fg=green,bold'
  typeset -g HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='bg=default,fg=red,bold'
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  (( $+terminfo[kcuu1] )) && bindkey -- "$terminfo[kcuu1]" history-substring-search-up
  (( $+terminfo[kcud1] )) && bindkey -- "$terminfo[kcud1]" history-substring-search-down
  bindkey -M emacs '^P' history-substring-search-up
  bindkey -M emacs '^N' history-substring-search-down
}

# =============================================================================
# DAILY FASTFETCH
# =============================================================================
# One system-info splash per day, not one per shell.
_storm_daily_fetch() {
  (( $+commands[fastfetch] )) || return 0
  [[ -t 1 ]] || return 0
  local stamp="$STORM/state/.fastfetch-day" today
  today="$(date +%Y-%m-%d)"
  [[ -f $stamp && $(<"$stamp") == "$today" ]] && return 0
  command mkdir -p "${stamp:h}" 2>/dev/null
  print -r -- "$today" > "$stamp" 2>/dev/null
  command fastfetch
}
[[ -o interactive ]] && _storm_daily_fetch
