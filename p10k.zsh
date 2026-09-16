# p10k.zsh - Storm's Powerlevel10k configuration.
#
# Hand-tuned "lean" style: no background colours, no powerline arrows, plain
# Unicode only (POWERLEVEL9K_MODE=unicode deliberately avoids Nerd Font
# private-use glyphs -- lab terminals over SSH rarely have them).
#
# Sourced from storm_zshrc right after powerlevel10k is loaded by zinit.
# To pick a completely different look instead, run `p10k configure`.

'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] && p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] && p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] && p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  unsetopt glob_dots

  # Two-line prompt: context (dir + git) on the first line, the input cursor
  # on its own line below, right-hand side carries status/clock details.
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon
    dir
    vcs
    newline
    prompt_char
  )
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status
    command_execution_time
    background_jobs
    time
  )

  typeset -g POWERLEVEL9K_MODE=unicode
  typeset -g POWERLEVEL9K_ICON_PADDING=none
  typeset -g POWERLEVEL9K_DISABLE_HOT_RELOAD=true
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

  # quiet: never print the "console output before instant prompt" warning.
  # The ZDOTDIR shim sources the user's ~/.zshrc before Storm, and whatever
  # that file prints is none of our business.
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

  # Mark prompt boundaries for the terminal (jump between prompts, etc.).
  typeset -g POWERLEVEL9K_TERM_SHELL_INTEGRATION=true

  # Past prompts collapse to a short marker; keeps scrollback readable.
  typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

  # --- os_icon ---------------------------------------------------------------
  typeset -g POWERLEVEL9K_OS_ICON_FOREGROUND=244

  # --- dir ---------------------------------------------------------------------
  typeset -g POWERLEVEL9K_DIR_FOREGROUND=39
  # Truncate the middle of very long paths, keeping first and last parts.
  typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_middle
  typeset -g POWERLEVEL9K_SHORTEN_DIR_LENGTH=60
  typeset -g POWERLEVEL9K_DIR_HYPERLINK=false
  typeset -g POWERLEVEL9K_DIR_SHOW_WRITABLE=v3

  # --- vcs (git) -----------------------------------------------------------------
  typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=76
  typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=178
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND=190
  typeset -g POWERLEVEL9K_VCS_CONFLICTED_FOREGROUND=196
  typeset -g POWERLEVEL9K_VCS_LOADING_FOREGROUND=244
  # Don't choke on huge repos: give up diffing beyond this many index entries.
  typeset -g POWERLEVEL9K_VCS_MAX_INDEX_SIZE_DIRTY=100000
  typeset -g POWERLEVEL9K_VCS_STAGED_ICON='+'
  typeset -g POWERLEVEL9K_VCS_UNSTAGED_ICON='!'
  typeset -g POWERLEVEL9K_VCS_UNTRACKED_ICON='?'
  typeset -g POWERLEVEL9K_VCS_INCOMING_CHANGES_ICON='<'
  typeset -g POWERLEVEL9K_VCS_OUTGOING_CHANGES_ICON='>'

  # --- prompt_char -----------------------------------------------------------
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=76
  typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND=196
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIINS_CONTENT_EXPANSION='❯'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VICMD_CONTENT_EXPANSION='❮'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIVIS_CONTENT_EXPANSION='V'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_{OK,ERROR}_VIOWR_CONTENT_EXPANSION='▶'
  typeset -g POWERLEVEL9K_PROMPT_CHAR_OVERWRITE_STATE=true

  # --- status ------------------------------------------------------------------
  # Only render when the last command failed; green is implicit in the char.
  typeset -g POWERLEVEL9K_STATUS_EXTENDED_STATES=true
  typeset -g POWERLEVEL9K_STATUS_OK=false
  typeset -g POWERLEVEL9K_STATUS_ERROR=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_FOREGROUND=196
  typeset -g POWERLEVEL9K_STATUS_ERROR_VISUAL_IDENTIFIER_EXPANSION='✘'
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_SIGNAL_FOREGROUND=196
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE=true
  typeset -g POWERLEVEL9K_STATUS_ERROR_PIPE_FOREGROUND=196

  # --- command_execution_time ------------------------------------------------
  # Show how long the last command took once it exceeded 5 seconds.
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=5
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_PRECISION=0
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FOREGROUND=178
  typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_FORMAT='d h m s'

  # --- background_jobs -----------------------------------------------------
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_FOREGROUND=70
  typeset -g POWERLEVEL9K_BACKGROUND_JOBS_VERBOSE=false

  # --- time ----------------------------------------------------------------------
  typeset -g POWERLEVEL9K_TIME_FOREGROUND=66
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
  typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=true
}

(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
