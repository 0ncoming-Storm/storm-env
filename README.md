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

2. **Audit every path the scripts touch.** They should all be derived from `$USER`, `$HOME` or
   `$STORM_REPO` now, but check before trusting them — an earlier revision of this repo hardcoded
   a foreign username into `storm-clean`'s `rm -rf`. Grep for it yourself:

   ```bash
   grep -rn 'rm -rf' *.sh storm-pkg storm_bashrc
   ```

   Every path should read `$USER`, `$HOME`, `$STORM` or `$STORM_REPO`. If you see a literal
   username, stop and fix it. `storm-clean` deletes `$STORM_REPO` and `$STORM` and now asks for
   confirmation first — but it is still a recursive delete, so read it before running it.

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

# First-time install: downloads everything into /tmp/$USER-storm
bash "$STORM_REPO/bootstrap.sh"

# Make it load on every shell
cat >> ~/.bashrc <<'EOF'
export STORM_REPO="$HOME/.storm-env"
source "$STORM_REPO/storm_bashrc"
EOF

exec bash
```

`export STORM_REPO` is optional — both shell files now default it to `$HOME/.storm-env` and export
it — but set it explicitly if you clone anywhere else. Older revisions used it in 15 places while
defining it nowhere, which left an empty `PATH` entry and resolved the auto-rebuild to
`/bootstrap.sh`.

First run takes a few minutes — it pulls eight GitHub releases and clones the Neovim plugins.

## Requirements

| Dependency | Required | Used for |
|---|---|---|
| `bash`, `curl`, `git`, `tar` | Yes | Everything |
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

Everything except Neovim is declared in `packages.tsv`:

| Package | Source | Why |
|---|---|---|
| `tmux` | `axetroy/tmux-builds` | **Broken** — see Known issues |
| `rg` | `BurntSushi/ripgrep` | Search |
| `lazygit` | `jesseduffield/lazygit` | Git TUI |
| `fzf` | `junegunn/fzf` | Fuzzy finding |
| `eza` | `eza-community/eza` | `ls` replacement (aliased to `ls`) |
| `jq` | `jqlang/jq` | JSON on the command line |
| `fastfetch` | `fastfetch-cli/fastfetch` | System info |

**Neovim** bypasses the manifest and is special-cased in `bootstrap.sh`: pinned URL, extracted to
`$STORM/nvim-app`, symlinked into `$STORM/bin`.

## Layout

```
storm-env/
├── bootstrap.sh      # Installer. Idempotent — safe to re-run.
├── storm_bashrc      # Shell env — the file to source from .bashrc
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
`git add packages.tsv bootstrap.sh storm-pkg storm_bashrc`, commits, pushes, and then **re-runs
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

## Known issues

### Open

- **`tmux` does not install.** `axetroy/tmux-builds` returns HTTP 404 from the GitHub API — the
  repo is gone. `get_download_url` fails both the API call and the HTML scrape, so bootstrap prints
  `[X] Failed to fetch download URL for tmux` and moves on. Nothing else breaks (the tmux
  auto-attach is guarded by `command -v tmux`), but the manifest row is dead weight. There is no
  drop-in replacement: `nelsonenzo/tmux-appimage` ships `tmux.appimage` (needs FUSE, often
  unavailable on locked-down lab machines), and `tmux/tmux` publishes only a source tarball.
  **This needs a decision** — pin a maintained static build, or drop the row.
- **`example.lua` is 190 lines of dead code.** It returns an empty spec on line 3.
- **No integrity checking.** Downloads are neither checksum- nor signature-verified, despite
  ripgrep publishing `.sha256` files alongside every asset.
- **The auto-rebuild blocks your shell.** If `/tmp` was wiped, the first shell after login sits in
  `bootstrap.sh` for minutes before giving you a prompt.
- **No test suite and no CI.** Verification is `bash -n` plus targeted tests of changed paths.
- **No license at the repository root.**

### Fixed

Each of these was verified by test, not just by reading:

- `storm-clean` hardcoded `/tmp/lorba197*` — a foreign username — and `rm -rf .storm-env` relative
  to your cwd. Now uses `$STORM` and `$STORM_REPO`, and confirms first.
- `curl -sL` had no `--fail`. A 404 exits 0 and writes its error body, so a failed download became
  a 9-byte executable that was `chmod +x`'d and then skipped forever as "already installed". All
  fetches now use `-fsSL` and validate before promoting.
- A dangling `~/.config/nvim` symlink passes `[ -L ]`, so once broken it was never relinked.
- The relink branch ran `rm -rf "$HOME/.config/nvim"`, destroying a pre-existing config. Now
  backed up with a timestamp.
- `while read` on a manifest without a trailing newline silently dropped the last package.
- `exec tmux` fired on non-interactive SSH, breaking `scp`, `sftp`, `rsync` and git-over-ssh.
- `GREP_OPTIONS` has been ignored since grep 2.21.
- Re-sourcing appended a duplicate copy of every `PATH` entry.
- `alias ls=eza` applied even when `eza` was missing, leaving no `ls` at all.
- `storm-pkg remove` interpolated the package name into a `sed` regex — `lib.foo` also deleted
  `libXfoo`. Now an exact `awk` field compare.
- `bootstrap.log` grew without bound; now rotated to `.log.old`.
- `bind` warned "line editing not enabled" on every non-interactive source.
- `storm-pkg add`/`remove` exited 1 when you declined the push prompt (`[[ ]] && cmd` as the last
  statement), so `storm-pkg add x && ...` silently skipped everything after it.
- **tree-sitter removed entirely.** `no-treesitter.lua` already disabled `nvim-treesitter`, so the
  npm/cargo CLI build and the `+TSUpdateSync` parser sync were both wasted work. Gone from
  `bootstrap.sh`; `npm`/`cargo` are no longer dependencies.
- **`mini.animate` consolidated.** `remote.lua` disabled `echasnovski/mini.animate` — a repo path
  `mini-animate.lua` had already retired, making the line a no-op that contradicted the other file.
  `mini-animate.lua` is now the single source of truth.
- **`init.sh` deleted.** It duplicated `storm_bashrc` and nothing sourced it. Source
  `storm_bashrc`.

## License

There is no license at the repository root, so as published this is all-rights-reserved — fork it
for yourself, don't redistribute. `nvim/LICENSE` is the Apache-2.0 license that ships with the
upstream LazyVim starter and covers that directory only.
