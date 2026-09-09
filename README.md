# ⛈️ Storm

A disposable development environment for machines you don't control.

Storm installs a full toolchain — Neovim, tmux, ripgrep, fzf, lazygit, eza, jq, fastfetch — into
`/tmp`, wires a LazyVim config into `$HOME/.config`, and rebuilds itself from Git whenever `/tmp`
gets wiped. Config survives; binaries don't have to.

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

2. **Change the hardcoded username in the scripts.** `storm_bashrc` contains paths that are mine,
   not yours:

   | Line | Current | Change to |
   |---|---|---|
   | `storm_bashrc:91` | `rm -rf /tmp/lorba197*` | `rm -rf /tmp/$USER-storm*` |
   | `storm_bashrc:90` | `rm -rf .storm-env` (relative to your cwd) | `rm -rf "$STORM_REPO"` |
   | `bootstrap.sh:6` | `STORM_REPO="$HOME/.storm-env"` | only if you clone elsewhere |

   The `storm-clean` function is a `rm -rf` with no confirmation. Read it before you run it.

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

# First-time install: downloads everything into /tmp/$USER-storm
bash "$STORM_REPO/bootstrap.sh"

# Make it load on every shell
cat >> ~/.bashrc <<'EOF'
export STORM_REPO="$HOME/.storm-env"
source "$STORM_REPO/storm_bashrc"
EOF

exec bash
```

`export STORM_REPO` is not optional. It's referenced throughout `storm_bashrc` and `init.sh` but
only ever defined locally inside `bootstrap.sh`, so if you skip it your `PATH` gets an empty entry
and the auto-rebuild path resolves to `/bootstrap.sh`.

First run takes a few minutes — it pulls eight GitHub releases, clones Neovim plugins, and
optionally compiles the tree-sitter CLI.

## Requirements

| Dependency | Required | Used for |
|---|---|---|
| `bash`, `curl`, `git`, `tar` | Yes | Everything |
| `unzip` | Only for zip-format assets | Some releases ship `.zip` |
| `npm` **or** `cargo` | Optional | Building the tree-sitter CLI |
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

Everything except Neovim and tree-sitter is declared in `packages.tsv`:

| Package | Source | Why |
|---|---|---|
| `tmux` | `axetroy/tmux-builds` | Static builds; portable session persistence over SSH |
| `rg` | `BurntSushi/ripgrep` | Search |
| `lazygit` | `jesseduffield/lazygit` | Git TUI |
| `fzf` | `junegunn/fzf` | Fuzzy finding |
| `eza` | `eza-community/eza` | `ls` replacement (aliased to `ls`) |
| `jq` | `jqlang/jq` | JSON on the command line |
| `fastfetch` | `fastfetch-cli/fastfetch` | System info |

Two packages bypass the manifest and are special-cased in `bootstrap.sh`:

- **Neovim** — pinned URL, extracted to `$STORM/nvim-app`, symlinked into `$STORM/bin`.
- **tree-sitter CLI** — built from `npm install -g tree-sitter-cli` or `cargo install`, whichever
  toolchain is present.

## Layout

```
storm-env/
├── bootstrap.sh      # Installer. Idempotent — safe to re-run.
├── init.sh           # Minimal shell env (aliases + auto-rebuild)
├── storm_bashrc      # Full shell env (the one to source)
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
| `/tmp/$USER-storm/bin` | All installed binaries |
| `/tmp/$USER-storm/{share,state,cache}` | Neovim plugins, LSP servers, undo files, caches |
| `/tmp/$USER-storm/bootstrap.log` | Full log of the last sync |

`XDG_CONFIG_HOME` stays `$HOME/.config`; the other three XDG variables are redirected into `/tmp`.
That's the entire trick — it keeps your config portable while keeping the several hundred MB of
plugin state somewhere that doesn't count against a home-directory quota.

## Commands

### `storm-pkg` — manage the manifest

| Command | Effect |
|---|---|
| `storm-pkg list` | Print declared packages |
| `storm-pkg add <name> <repo> <pattern>` | Append a row, then offer to commit + push |
| `storm-pkg remove <name>` | Delete a row, then offer to commit + push (`rm` works as a synonym) |
| `storm-pkg sync [message]` | Commit, push, and rebuild locally |

`add` and `remove` prompt `Commit and push to GitHub now? (y/N)`. `sync` runs
`git add packages.tsv bootstrap.sh init.sh storm-pkg`, commits, pushes, and then **re-runs
`bootstrap.sh`** — expect a few minutes.

### `storm-*` shell functions

| Function | Effect |
|---|---|
| `storm-update` | `git pull` + rebuild + reload shell config |
| `storm-rebuild` | Wipe `/tmp/$USER-storm`, pull, reinstall, reload |
| `storm-logs` | Print `/tmp/$USER-storm/bootstrap.log` |
| `storm-clean` | **`rm -rf` with no confirmation** — see the fork warning above |

### Aliases

`vim` → `nvim`, `ls` → `eza`, `lg` → `lazygit`, `n` → `nvim`, plus `la`, `ll`, `..`, `c`, `mem`,
`cpu`, `usage`, `grep` (colourised), a `build` wrapper around `g++`, and `mkcd`.

## Adding a package

`packages.tsv` is tab-separated with three columns:

```
name <TAB> owner/repo <TAB> asset-pattern
```

The pattern is a `grep -E` regex matched against release asset filenames — use `|` for alternates
when a project names its assets inconsistently across versions.

```bash
storm-pkg add bat sharkdp/bat 'x86_64-unknown-linux-gnu.tar.gz'
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
| `remote.lua` | The important one. Disables `noice`, `bufferline`, `flash`, and `mini.animate`; turns off treesitter indentation and `update_in_insert` diagnostics. Cuts keystroke latency over SSH noticeably. |
| `no-treesitter.lua` | Disables `nvim-treesitter` entirely and falls back to Vim's built-in syntax highlighting. |
| `mini-animate.lua` | Re-points `mini.animate` at the current `nvim-mini/mini.animate` repo with linear scroll/resize timings. |
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
anything else is treated as a raw binary. Everything is `chmod +x`'d into `$STORM/bin`.

The whole run is `tee`'d to `/tmp/$USER-storm/bootstrap.log`, and each installer short-circuits if
the binary already exists — so re-running `bootstrap.sh` only fetches what's missing.

## Troubleshooting

**`[Storm] Missing /tmp binaries. Rebuilding...`** on every shell — normal after a reboot or a
`/tmp` cleanup. It means the auto-rebuild path is working.

**`API Warning: API rate limit exceeded`** — you've hit unauthenticated limits. Set
`GITHUB_TOKEN`, or wait it out; the scraper fallback will usually still work.

**`[X] Web scrape failed to match pattern`** — the asset pattern in `packages.tsv` no longer
matches anything upstream ships. Check the project's latest release and update the pattern.

**`[X] Extraction failed: '<name>' executable not found in archive`** — the archive layout
changed, or the binary inside isn't named exactly `<name>`. Unpack it by hand and check.

**Neovim plugins missing** — run `nvim --headless "+Lazy! sync" +qa`. `bootstrap.sh` does this at
the end of every sync, but it's silenced with `|| true`.

**Everything is broken** — `storm-rebuild` wipes `/tmp/$USER-storm` and reinstalls from scratch.
Nothing you care about lives there.

## Known quirks

Things that are rough edges rather than features:

- `storm_bashrc:91` hardcodes `/tmp/lorba197*`. This is the username-leak the fork warning is
  about — fix it before running `storm-clean` on a shared machine.
- `storm_bashrc:90` runs `rm -rf .storm-env` relative to your current directory, not `$STORM_REPO`.
- `bootstrap.sh` installs the tree-sitter CLI, while `no-treesitter.lua` disables
  `nvim-treesitter`. The CLI install is currently wasted work.
- `remote.lua` disables `echasnovski/mini.animate` while `mini-animate.lua` installs
  `nvim-mini/mini.animate`. Only the latter takes effect.
- `$STORM_REPO` is used everywhere but defined nowhere outside `bootstrap.sh`. Export it yourself.
- There is no test suite and no CI. Verification is `bash -n` on the four scripts and running them.

## License

There is no license at the repository root, so as published this is all-rights-reserved — fork it
for yourself, don't redistribute. `nvim/LICENSE` is the Apache-2.0 license that ships with the
upstream LazyVim starter and covers that directory only.
