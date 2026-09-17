# ⛈️ Storm

A disposable development environment for machines you don't control.

Storm installs a full toolchain — a static zsh, Neovim, tmux, ripgrep, fzf, lazygit, eza, jq,
fastfetch, zoxide, bat — into `/var/tmp`, wires a LazyVim config into `$HOME/.config`, and rebuilds
itself from Git whenever `/var/tmp` gets wiped. Config survives; binaries don't have to.

The interactive shell is **zsh**: `storm_bashrc` stays as the bootstrap entry point and hands off
to zsh as soon as one is found. `storm_zshrc` is currently a deliberately minimal core — a
reliable prompt, working line editing, history and completion, with no plugins and no network
dependency at startup. Everything else (aliases, fzf, zoxide, the zinit/Powerlevel10k suite) is
parked and comes back in a follow-up phase, once the core is proven on the lab machines — on
hostile machines a plain working shell beats a fancy broken one.

Built for shared lab accounts and restricted shells: no sudo, no root, no package manager, no
persistence guarantee between sessions.

---

## ⚠️ Before you use this — fork it first

**This is a personal environment, not a published tool. Do not clone it directly.**

Storm's whole update model is `git pull` from whatever `origin` points at. If you clone this repo
and run it, every future commit I push lands on *your* machine — including anything I break, and
including the school-specific overrides in `storm_bashrc` that assume my lab's terminal and
compiler flags.

If you want this:

1. **Fork it** to your own GitHub account, and clone your fork:

   ```bash
   git clone https://github.com/YOUR-USERNAME/storm-env.git ~/.storm-env
   ```

2. **Audit every path the scripts touch.** They should all be derived from `$USER`, `$HOME` or
   `$STORM_REPO` now, but check before trusting them — an earlier revision of this repo hardcoded
   a foreign username into `storm-clean`'s `rm -rf`. Grep for it yourself:

   ```bash
   grep -rn 'rm -rf' *.sh storm-pkg storm_bashrc storm_zshrc
   ```

   Every path should read `$USER`, `$HOME`, `$STORM` or `$STORM_REPO`. If you see a literal
   username, stop and fix it. (The old `storm-clean` recursive-delete function is gone;
   `storm-rebuild` only ever wipes `$STORM`.)

   If you clone somewhere other than `~/.storm-env`, `export STORM_REPO=/your/path` before
   sourcing. Both shell files default it to `$HOME/.storm-env`.

3. **Decide what to do with upstream.** Either drop the remote entirely
   (`git remote remove origin`) so nothing auto-pulls, or keep it as `upstream` and pull
   deliberately. Never point `storm-update` at a repo you don't control.

4. **Strip what's mine.** The `SCHOOL OVERRIDES` block in `storm_bashrc` (konsole terminal
   detection, `g++ -pedantic-errors`, colourless `ls`) and the alias/function set are tailored to
   my courses. Edit them or delete them.

---

## Quick start

```bash
git clone https://github.com/YOUR-USERNAME/storm-env.git ~/.storm-env
export STORM_REPO="$HOME/.storm-env"

# First-time install: downloads everything into /var/tmp/$USER-storm
# (includes a static, relocatable zsh, so no root / no system zsh needed)
bash "$STORM_REPO/bootstrap.sh"

# Make it load on every shell. bash is the entry point; it execs zsh once one
# is found (Storm's own build first, then the system's).
cat >> ~/.bashrc <<'EOF'
export STORM_REPO="$HOME/.storm-env"
source "$STORM_REPO/storm_bashrc"
EOF

exec bash
```

That is the only dotfile you have to touch. `storm_bashrc` points `ZDOTDIR` at the repo's
`zdotdir/` shim before exec'ing zsh, and the shim chains your own `~/.zshrc` (if any) and then
loads `storm_zshrc` — so your existing zsh config is preserved and no `~/.zshrc` edit is required.
If you'd rather start zsh directly, add `source "$STORM_REPO/storm_zshrc"` to your `~/.zshrc`;
`storm_zshrc` is idempotent, so both paths coexist. Set `STORM_KEEP_BASH=1` to skip the handoff.

`export STORM_REPO` is optional — both shell files now default it to `$HOME/.storm-env` and export
it — but set it explicitly if you clone anywhere else. Older revisions used it in 15 places while
defining it nowhere, which left an empty `PATH` entry and resolved the auto-rebuild to
`/bootstrap.sh`.

First run takes a few minutes — it pulls a handful of GitHub releases (zsh, Neovim, tmux, ripgrep,
fzf, lazygit, eza, jq, fastfetch, zoxide, bat) and clones the Neovim plugins. On first zsh start,
zinit then clones the plugin suite into `/var/tmp` (~10 MB).

## Requirements

| Dependency | Required | Used for |
|---|---|---|
| `bash`, `curl`, `git`, `tar` | Yes | Installer, plus fallback shell if no zsh exists |
| `zsh` | No | Storm installs its own static build (`romkatv/zsh-bin`) when absent |
| `unzip` | Only for zip-format assets | Some releases ship `.zip` |
| `GITHUB_TOKEN` | Optional | Avoiding API rate limits |
| `tmux` | Optional | Auto-attached on SSH once installed |

**Linux x86_64 only.** Every asset pattern in `packages.tsv` and the pinned Neovim URL assume
`x86_64` Linux. ARM and macOS will resolve no matching assets.

**Set `GITHUB_TOKEN` if you can.** Unauthenticated GitHub API access is limited to 60 requests per
hour per IP — enough for one clean sync, not enough for repeated rebuilds on a shared lab machine.
Without it, Storm falls back to HTML scraping (see [How it works](#how-it-works)), which is slower
and more fragile.

```bash
export GITHUB_TOKEN="ghp_..."   # add to ~/.bashrc to persist
```

## What gets installed

Everything except Neovim and Zsh is declared in `packages.tsv`:

| Package | Source | Why |
|---|---|---|
| `tmux` | `axetroy/tmux-builds` | Terminal multiplexer |
| `rg` | `BurntSushi/ripgrep` | Search |
| `lazygit` | `jesseduffield/lazygit` | Git TUI |
| `fzf` | `junegunn/fzf` | Fuzzy finding |
| `eza` | `eza-community/eza` | `ls` replacement (aliased to `ls`) |
| `jq` | `jqlang/jq` | JSON on the command line |
| `fastfetch` | `fastfetch-cli/fastfetch` | System info |
| `zoxide` | `ajeetdsouza/zoxide` | Directory jumping (`z partial`, `zi`) |
| `bat` | `sharkdp/bat` | File previews for fzf-tab |

**Neovim** and **Zsh** bypass the manifest and are special-cased in `bootstrap.sh`: pinned URL,
extracted to `$STORM/nvim-app` / `$STORM/zsh-app`, symlinked into `$STORM/bin`. Zsh comes from
[`romkatv/zsh-bin`](https://github.com/romkatv/zsh-bin) — a statically linked, relocatable build
that needs no root and no system libraries. After extraction, `bootstrap.sh` runs the archive's
`relocate` script, which rewrites the install paths baked into the binary so it runs from
`/var/tmp`.

## Layout

```
storm-env/
├── bootstrap.sh      # Installer. Idempotent — safe to re-run.
├── storm_bashrc      # Bootstrap env + fallback shell — sourced from .bashrc
├── storm_zshrc       # The core interactive shell — sourced by the shim/.zshrc
├── p10k.zsh          # Powerlevel10k prompt configuration (parked — next phase)
├── zdotdir/.zshrc    # ZDOTDIR shim: chains your ~/.zshrc, then storm_zshrc
├── storm-pkg         # CLI for editing packages.tsv
├── packages.tsv      # The package manifest
└── nvim/             # LazyVim config, symlinked to ~/.config/nvim
    └── lua/plugins/  # Per-plugin overrides
```

At runtime, Storm splits across two locations:

| Location | Contents |
|---|---|
| `$HOME/.config` | `nvim` symlink, and anything you save |
| `$HOME/.bashrc` | The two lines that source Storm |
| `/var/tmp/$USER-storm/bin` | All installed binaries |
| `/var/tmp/$USER-storm/zsh-app` | The relocated static zsh (zsh-bin) |
| `/var/tmp/$USER-storm/share/zinit` | zinit + its cloned zsh plugins (re-cloned after a wipe) |
| `/var/tmp/$USER-storm/state/zsh` | zsh history |
| `/var/tmp/$USER-storm/{share,state,cache}` | Neovim plugins, LSP servers, undo files, caches |
| `/var/tmp/$USER-storm/bootstrap.log` | Full log of the last sync |

`XDG_CONFIG_HOME` stays `$HOME/.config`; the other three XDG variables are redirected into `/var/tmp`.
That's the entire trick — it keeps your config portable while keeping the several hundred MB of
plugin state somewhere that doesn't count against a home-directory quota.

## The shell: bash hands off to zsh

bash stays the entry point (it's what login shells and `~/.bashrc` know how to source), but the
moment an interactive bash finishes bootstrapping, it `exec`s zsh and gets out of the way:

| File | Role |
|---|---|
| `storm_bashrc` | Environment bootstrap (PATH, XDG vars), `storm-*` functions, auto-rebuild, and the handoff. Also a complete fallback shell if no zsh exists. |
| `zdotdir/.zshrc` | The ZDOTDIR shim. `storm_bashrc` points `ZDOTDIR` at `zdotdir/` before exec'ing zsh; the shim sources your own `~/.zshenv`/`~/.zshrc` first, then `storm_zshrc`. |
| `storm_zshrc` | The core shell: hostile-option guard, reliable prompt, options, history, completion, keybindings, and the `storm-update`/`rebuild`/`logs`/`doctor` functions. Idempotent, so it is also safe to source directly from `~/.zshrc`. |
| `p10k.zsh` | Powerlevel10k theme. Parked — loaded in a later phase, not by the current core. |

The zsh binary itself is Storm's: `bootstrap.sh` installs the static, relocatable
[romkatv/zsh-bin](https://github.com/romkatv/zsh-bin) build into `$STORM/zsh-app` and symlinks it
into `$STORM/bin`, so the handoff works even on hosts with no zsh at all. Precedence is Storm's
zsh → the host's zsh → stay in bash.

What `storm_zshrc` loads (the core — always, no network, no plugins):

- **A hostile-option guard** — `unsetopt POSIX_IDENTIFIERS KSH_ARRAYS` before anything else runs.
  Lab machines that set these in `/etc/zshrc` break `#name` length arithmetic (the
  `zsh: bad math expression: operator expected at '...'` errors) and 1-based arrays across the
  whole zsh plugin ecosystem; Storm strips them on entry.
- **A reliable prompt** — green `user@host`, blue dir, magenta git branch, dim clock on the right.
  It is re-applied after every command, so lab `/etc/zshrc` precmd hooks that re-set the prompt
  (the classic "bare system prompt survives a full load" bug) can't win.
- **Working line editing over SSH** — `KEYTIMEOUT=100`, re-pinned Backspace (both DEL and ^H) /
  Ctrl-W / Ctrl-U / Ctrl-K on top of emacs keybindings.
- Plain `compinit` completion (the host's own, `-u` to skip the insecure-dir audit on shared
  machines, with a menu, case-insensitive + substring matching and caching), plus million-line
  shared history and the standard shell options.

Parked for the next phase (not loaded by the current core): the alias set, fzf, zoxide, the
daily fastfetch splash, and the zinit plugin suite (powerlevel10k, fzf-tab,
fast-syntax-highlighting, zsh-autosuggestions, history-substring-search, zsh-completions).
`p10k.zsh` stays in the repo so that phase is a re-add, not a rewrite. When the suite returns it
will self-bootstrap into `/var/tmp` (a wiped `/var/tmp` re-clones on the next shell) and stay
gated on `is-at-least 5.7.1`. `STORM_KEEP_BASH=1` still skips the bash→zsh handoff.

## Commands

### `storm-pkg` — manage the manifest

| Command | Effect |
|---|---|
| `storm-pkg list` | Print declared packages |
| `storm-pkg add <name> <repo> <pattern>` | Append a row, then offer to commit + push |
| `storm-pkg remove <name>` | Delete a row, then offer to commit + push (`rm` works as a synonym) |
| `storm-pkg sync [message]` | Commit, push, and rebuild locally |

`add` and `remove` prompt `Commit and push to GitHub now? (y/N)`. `sync` runs
`git add packages.tsv bootstrap.sh storm-pkg storm_bashrc storm_zshrc p10k.zsh zdotdir/.zshrc`,
commits, pushes, and then **re-runs `bootstrap.sh`** — expect a few minutes.

### `storm-*` shell functions

| Function | Effect |
|---|---|
| `storm-update` | `git pull` + (zinit update, once the plugin suite is back) + rebuild + `exec zsh` to reload |
| `storm-rebuild` | Wipe `/var/tmp/$USER-storm`, pull, reinstall, `exec zsh` to reload |
| `storm-logs` | Print `/var/tmp/$USER-storm/bootstrap.log` |
| `storm-doctor` | One-shot shell diagnosis: zsh binary, hostile options, precmd hooks, prompt values, KEYTIMEOUT, git branch — paste it when a machine's shell looks wrong |

`storm-update` and `storm-rebuild` finish by re-exec'ing zsh, so the whole environment — bashrc,
zshrc, plugins — reloads cleanly in place.

### Aliases

The bash fallback keeps its originals (`vim` → `nvim`, `ls` → `eza`, `lg` → `lazygit`, `n`, `la`,
`ll`, `..`, `c`, `mem`, `cpu`, `usage`, colourised `grep`, `build`, `mkcd`) — those still work.
The zsh side currently defines **no aliases at all** (phase 1 is a working shell, not a toolkit):
the eza suite, git shorthand, global aliases, suffix aliases, dir-stack aliases, `extract`/
`build`/`mkcd`/`start-report`/`stop-report`, and the extra widgets (`Esc Esc` → sudo,
`Ctrl-X Ctrl-E`, `Ctrl-S` search, `zmv`) all come back in the next phase.

## Adding a package

`packages.tsv` is tab-separated with three columns:

```
name <TAB> owner/repo <TAB> asset-pattern
```

The pattern is a `grep -E` regex matched against release asset filenames — use `|` for alternates
when a project names its assets inconsistently across versions.

```bash
storm-pkg add delta dandavison/delta 'x86_64-unknown-linux-musl.tar.gz'
```

To find the right pattern, open the project's releases page, look at the Linux x86_64 asset
filename, and copy the distinctive middle part. If a package fails to install later, an upstream
asset rename is the most likely cause — run `storm-logs` and look for
`Web scrape failed to match pattern`.

## Neovim

The `nvim/` directory is a [LazyVim](https://github.com/LazyVim/LazyVim) starter. `bootstrap.sh`
**symlinks** it to `$HOME/.config/nvim` rather than copying it, so edits in the repo take effect
immediately and are trivially version-controlled.

Custom specs in `nvim/lua/plugins/`:

| File | Purpose |
|---|---|
| `remote.lua` | The important one. Disables `noice`, `bufferline` and `flash`, and turns off `update_in_insert` diagnostics. Cuts keystroke latency over SSH noticeably. |
| `no-treesitter.lua` | Disables `nvim-treesitter` entirely and falls back to Vim's built-in syntax highlighting. Tree-sitter is not used at all — no CLI, no parsers. |
| `mini-animate.lua` | Single source of truth for `mini.animate`. Re-points it at the current `nvim-mini/mini.animate` repo with linear scroll/resize timings. Flip `enabled = false` here to turn animations off. |
| `example.lua` | LazyVim's sample spec. **Inert** — it returns early on line 3. |

## How it works

The interesting part is `get_download_url()` in `bootstrap.sh`. Every package is installed from its
*latest* GitHub release, which means the URL has to be discovered rather than hardcoded. Storm
tries three strategies in order:

1. **GitHub API** — `api.github.com/repos/<repo>/releases/latest`, filtered by the asset pattern.
   Uses `GITHUB_TOKEN` if set.
2. **HTML scrape** — `github.com/<repo>/releases/latest`, regex over the download links.
3. **Expanded assets** — `github.com/<repo>/releases/expanded_assets/<tag>`, for releases with
   enough assets that GitHub collapses the list behind a "Show all" button.

Once a URL resolves, installation dispatches on the extension: `.tar.gz`/`.tgz` are streamed into
a scratch directory and the binary is located by name, `.zip` is extracted with `unzip -j`, and
anything else is treated as a raw binary. Everything is `chmod +x`'d into `$STORM/bin`. Neovim and
zsh take a detour instead: they extract full application trees into `$STORM/nvim-app` /
`$STORM/zsh-app` (zsh additionally runs its `relocate` script) and only a symlink lands in
`$STORM/bin`.

The whole run is `tee`'d to `/var/tmp/$USER-storm/bootstrap.log`, and each installer short-circuits if
the binary already exists — so re-running `bootstrap.sh` only fetches what's missing.

## Troubleshooting

**`[Storm] Missing /var/tmp binaries. Rebuilding...`** on every shell — normal after a reboot or a
`/var/tmp` cleanup. It means the auto-rebuild path is working.

**`API Warning: API rate limit exceeded`** — you've hit unauthenticated limits. Set
`GITHUB_TOKEN`, or wait it out; the scraper fallback will usually still work.

**`[X] Web scrape failed to match pattern`** — the asset pattern in `packages.tsv` no longer
matches anything upstream ships. Check the project's latest release and update the pattern.

**`[X] Extraction failed: '<name>' executable not found in archive`** — the archive layout
changed, or the binary inside isn't named exactly `<name>`. Unpack it by hand and check.

**Neovim plugins missing** — run `nvim --headless "+Lazy! sync" +qa`. `bootstrap.sh` does this at
the end of every sync, but it's silenced with `|| true`.

**I land in bash, not zsh** — no zsh was found at handoff time. Run `bootstrap.sh` (it installs
Storm's static zsh into `$STORM/bin`) and open a new shell, or check that `STORM_KEEP_BASH` isn't
set. Force the fallback deliberately with `STORM_KEEP_BASH=1 bash`.

**`zsh: bad math expression: operator expected at '...'`** — a machine option (usually
`POSIX_IDENTIFIERS` in `/etc/zshrc`) is breaking `#name` length arithmetic. Storm unsets it on
entry (section 0.5 of `storm_zshrc`); if the error persists, something re-set it afterwards —
`storm-doctor`'s `hostile` line will show it.

**The prompt is the bare system one (`host%`)** — a lab `/etc/zshrc` prompt hook is winning. The
core prompt re-applies itself after every command and is registered last, so if the system prompt
still wins, something is re-setting it *between* prompts (a precmd hook installed after Storm's) —
run `storm-doctor` and check `precmd_functions`.

**The prompt is the bare system one (`host%`)** — a lab `/etc/zshrc` prompt hook is winning. The
core prompt re-applies itself after every command and is registered last, so if the system prompt
still wins, something re-set it *between* prompts (a precmd hook installed after Storm's) — run
`storm-doctor` and check its `precmds` line.

**zsh starts but looks bare or the prompt is garbage** (once the plugin suite is re-added) — the
suite only loads on zsh ≥ 5.7.1 with `git` available, and only after zinit could clone itself.
Check `zsh --version`, and look for clone errors under `$STORM/share/zinit`. For anything stranger
(dead keybindings), run `storm-doctor` and paste its output — it prints the raw `PROMPT`/`PS2`
values, hostile options, the precmd hooks in play, `KEYTIMEOUT`, and which zsh binary is running.

**`storm-rebuild` left me in a weird shell** — it finishes by `exec zsh`; if that failed, just run
`exec zsh` (or open a new shell) yourself.

**Everything is broken** — `storm-rebuild` wipes `/var/tmp/$USER-storm` and reinstalls from scratch.
Nothing you care about lives there.

## Known issues

### Open

- **`example.lua` is 190 lines of dead code.** It returns an empty spec on line 3.
- **No integrity checking.** Downloads are neither checksum- nor signature-verified, despite
  ripgrep publishing `.sha256` files alongside every asset.
- **The auto-rebuild blocks your shell.** If `/var/tmp` was wiped, the first shell after login sits in
  `bootstrap.sh` for minutes before giving you a prompt.
- **No test suite and no CI.** Verification is `bash -n` plus targeted tests of changed paths.
- **Zsh is pinned to 5.8.** It comes from `romkatv/zsh-bin`, which builds 5.8, not the latest zsh.
  The plugin suite is gated on `is-at-least 5.7.1`, so a newer *system* zsh also gets the full setup.
- **The handoff re-reads `~/.zshrc`.** The ZDOTDIR shim chains your `~/.zshrc` on top of Storm; if
  your `~/.zshrc` also sources `storm_zshrc`, the idempotency guard stops a double-load — but any
  other side effects in your `~/.zshrc` still run once, as intended.
- **`storm-pkg sync` assumes a clean push.** It commits the shell files and pushes without checking
  that `origin` is a repo you control — same caveat as `storm-update` in the fork warning above.
