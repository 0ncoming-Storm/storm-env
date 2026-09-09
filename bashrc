# .bashrc - Enhanced & Functional

# Source global definitions
if [ -f /etc/bashrc ]; then
  . /etc/bashrc
fi

# ==============================================================================
# ENVIRONMENT & PATH
# ==============================================================================
PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export PATH

# Force color support for common tools
export CLICOLOR=1
export GREP_OPTIONS='--color=auto'
# export SYSTEMD_PAGER=

# ==============================================================================
# PROMPT (Fancy & Readable)
# ==============================================================================
# [user@host directory] $ (with color-coded sections)
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# ==============================================================================
# GENERAL ALIASES & QUALITY OF LIFE
# ==============================================================================
alias ls='ls --color=auto'
alias la='ls -lah'
alias ll='ls -lh'
alias l='ls -CF'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias .3='cd ../../..'

#Tool shortcuts
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias h='history'
alias j='jobs -l'
alias c='clear'
alias n='nvim'

# ==============================================================================
# SCHOOL ENVIRONMENT OVERRIDES & FUNCTIONS
# ==============================================================================
# Apply restricted Konsole settings if forced into that terminal type
if [ "$TERM" == "konsole" ]; then
  alias g++='g++ -pedantic-errors -Wall -Wconversion -fdiagnostics-color=never'
  alias ls='ls --color=never'
fi

# Preserved School Wrapper: script
script() {
  if [ "$TERM" == "konsole" ]; then
    echo "You are already in a script! Do not run script within a script"
  else
    OLDTERM=$TERM
    TERM=konsole
    /usr/bin/script "$@"
    TERM=$OLDTERM
  fi
}

# Preserved School Wrapper: lpr
lpr() {
  if [ $# -eq 0 ]; then
    echo "To find out how to use lpr run 'man lpr'"
  else
    local switches=""
    local files=""

    while [ $# -gt 0 ]; do
      case $1 in
      -*) switches="${switches} $1" ;;
      *)
        files="${files} $1"
        stripbs $1
        ;;
      esac
      shift
    done
    /usr/bin/lpr ${switches} ${files}
  fi
}
cbcopy() {
  local data
  # Read stdin, base64 encode it, and strip newlines
  data=$(cat | base64 | tr -d '\r\n')

  if [ -n "$TMUX" ]; then
    # Inside tmux: Wrap with the DCS passthrough sequence
    printf "\033Ptmux;\033\033]52;c;%s\a\033\\\\" "$data"
  else
    # Outside tmux: Send the standard OSC 52 sequence
    printf "\033]52;c;%s\a" "$data"
  fi
}

# ==============================================================================
# BETTER HISTORY & AUTO-COMPLETE
# ==============================================================================
# Up/Down arrows search history based on what you've already typed
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Save up to 10,000 lines of history, ignore duplicates and space-prefixed commands
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups

# Append history immediately instead of overwriting on logout
shopt -s histappend

# Auto-correct minor directory spelling typos on 'cd'
shopt -s cdspell
# Case-insensitive tab-completion
bind 'set completion-ignore-case on'

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================
# Universal archive extractor
extract() {
  if [ -f "$1" ]; then
    case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz) tar xzf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.rar) unrar x "$1" ;;
    *.gz) gunzip "$1" ;;
    *.tar) tar xvf "$1" ;;
    *.tbz2) tar xjf "$1" ;;
    *.tgz) tar xzf "$1" ;;
    *.zip) unzip "$1" ;;
    *.Z) uncompress "$1" ;;
    *.7z) 7z x "$1" ;;
    *) echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}

# Create a directory and immediately enter it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# ==============================================================================
# USEFUL SCHOOL & DEV ALIASES
# ==============================================================================
# Quick system resource checks
alias mem='free -m -l -t'
alias cpu='top -o %CPU'
alias ports='netstat -tulanp'

# Quick disk usage for current folder
alias usage='du -sh * | sort -h'

# Quick C++ fast-compile & run helper
build() {
  g++ -Wall -Wextra "$1".cpp -o "$1" && ./"$1"
}

# ==============================================================================
# DYNAMIC & SEARCHABLE CHEAT SHEET SYSTEM
# ==============================================================================

# Custom Quick-Reference Database
cheat_db() {
  cat <<'EOF'
[c++] compile        g++ -Wall -Wextra main.cpp -o main
[c++] memory check   valgrind --leak-check=full ./main
[c++] gdb debug      gdb ./main -> run -> backtrace (bt)
[git] status         git status -s
[git] quick commit   git commit -am "message"
[git] branch graph   git log --oneline --graph --decorate --all
[tmux] new session   tmux new -s session_name
[tmux] list          tmux ls
[tmux] attach        tmux attach -t session_name
[tmux] detach        Ctrl+b then d
[tmux] split vert    Ctrl+b then %
[tmux] split horiz   Ctrl+b then "
[linux] disk quota   quota -s OR du -sh * | sort -h
[linux] active proc  ps aux | grep user
[linux] kill process kill -9 <PID>
[linux] find file    find . -name "*.cpp"
[linux] search text  grep -rnw '.' -e "search_term"
[linux] permissions  chmod 755 filename
[bash] source bashrc source ~/.bashrc
[bash] history search Ctrl+r
EOF
}

# Searchable Cheat Sheet Command
cheat() {
  local search_term="$1"

  # If no argument is passed, display everything with formatted categories
  if [ -z "$search_term" ]; then
    echo -e "\033[1;33m=== DYNAMIC CHEAT SHEET (Usage: cheat <search_term>) ===\033[0m\n"
    cheat_db | while read -r line; do
      # Colorize the [category] tag in cyan and the command description
      category=$(echo "$line" | grep -o '\[.*\]')
      rest=$(echo "$line" | sed 's/\[.*\]//')
      echo -e "\033[1;36m$category\033[0m $rest"
    done
    return 0
  fi

  # Perform a case-insensitive, colorized search across the database
  echo -e "\033[1;33m=== Search Results for '$search_term' ===\033[0m\n"
  cheat_db | grep -i --color=always "$search_term" | while read -r line; do
    category=$(echo "$line" | grep -o '\[.*\]')
    rest=$(echo "$line" | sed 's/\[.*\]//')
    echo -e "\033[1;36m$category\033[0m $rest"
  done
}

# Quick shortcut alias to add a note to your personal cheat sheet file
alias cheat-add='echo "" >> ~/.my_cheats.txt && nano ~/.my_cheats.txt'

# ==============================================================================
# STORM ENVIRONMENT (Self-Healing /tmp Workspace)
# ==============================================================================
export STORM="/tmp/$USER-storm"

# 1. Add Storm binaries directly to your PATH
export PATH="$STORM/bin:$PATH"

# 2. Redirect all XDG state/data/cache to /tmp so home quota stays under 40MB
export XDG_CONFIG_HOME="$STORM/config"
export XDG_DATA_HOME="$STORM/share"
export XDG_STATE_HOME="$STORM/state"
export XDG_CACHE_HOME="$STORM/cache"

# 3. Automatic Recovery Trigger
if [ ! -d "$STORM/bin" ]; then
  echo -e "\033[1;33m[Storm] Environment missing/wiped. Rebuilding...\033[0m"
  mkdir -p "$STORM"

  # Clone your config repo into /tmp
  git clone https://github.com/0ncoming-Storm/storm-env.git "$STORM/repo"

  # Execute installer
  if [ -f "$STORM/repo/bootstrap.sh" ]; then
    bash "$STORM/repo/bootstrap.sh"
  fi
fi

# 4. Tool Aliases
alias vim="nvim"
alias ls="eza"
alias lg="lazygit"

# Helper command to manually trigger updates or force a rebuild
storm-update() {
  if [ -d "$STORM/repo" ]; then
    echo "Updating Storm repository..."
    cd "$STORM/repo" && git pull
    bash "$STORM/repo/bootstrap.sh"
    cd - >/dev/null
  else
    echo "Repo missing. Reloading bashrc..."
    source ~/.bashrc
  fi
}

storm-rebuild() {
  echo "Wiping and rebuilding Storm environment..."
  rm -rf "$STORM"
  source ~/.bashrc
}

# ==============================================================================
# AUTO-START TMUX (SSH Sessions)
# ==============================================================================
if [ -n "$SSH_CONNECTION" ] && [ -z "$TMUX" ]; then
  # Verify tmux exists in PATH before attempting to exec
  if command -v tmux >/dev/null 2>&1; then
    exec tmux new-session -A -s main
  fi
fi

# Storm Environment Path
export PATH="/tmp/lorba197-storm/bin:$PATH"

