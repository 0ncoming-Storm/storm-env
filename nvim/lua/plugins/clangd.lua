-- lua/plugins/clangd.lua
-- Clangd tuned for the school VM: GCC-only headers, no system Clang.
--
-- The LazyVim `lang.clangd` extra (enabled in `lazyvim.json`) already
-- registers `clangd` in `nvim-lspconfig` and ensures Mason installs it:
--   servers.clangd = { cmd = {
--     "clangd", "--background-index", "--clang-tidy",
--     "--header-insertion=iwyu", "--completion-style=detailed",
--     "--function-arg-placeholders", "--fallback-style=llvm" } }
--
-- This file extends that table in-place for this host:
--   * `--query-driver=/usr/bin/**/g++*,...` -- whitelist the GCC
--     driver so clangd may ask g++ for its include paths (libstdc++
--     lives under /usr/include/c++/11 and
--     /usr/lib/gcc/x86_64-redhat-linux/11/include). Paired with the
--     global `clangd/config.yaml` below (Compiler: /usr/bin/g++), the
--     fallback compile command uses g++ and extraction succeeds even
--     with no compile_commands.json. Guarded on the driver existing.
--   * `--enable-config` -- read `.clangd` / `config.yaml` files so a
--     project can supply `CompileFlags` (e.g. `-std=c++11 -Wall`)
--     without editing Neovim.
--   * `--offset-encoding=utf-16` -- match the extra's
--     `capabilities.offsetEncoding = { "utf-16" }` so edit positions
--     stay consistent even if negotiation differs.
--   * `--background-index-priority=low` -- keep background indexing
--     for larger projects, but don't starve SSH responsiveness.
--   * Normalises the extra's bare `--function-arg-placeholders` to
--     `--function-arg-placeholders=true` for clangd 23, which rejects
--     the valueless form ("Value specified ... is invalid").
--
-- The Mason spec below is belt-and-suspenders: Mason's
-- `ensure_installed` also installs `clangd` when Mason loads,
-- independent of the lspconfig auto-install. Both paths are idempotent
-- and write into `$XDG_DATA_HOME/nvim/mason` -- which `storm_bashrc`
-- redirects into `/var/tmp/$USER-storm`, so nothing counts against
-- the home-directory quota. After `/var/tmp` is wiped, `bootstrap.sh`
-- pre-installs it again headlessly (see bootstrap.sh).
--
-- Global fallback flags live in the tracked `clangd/config.yaml`
-- (symlinked to `$XDG_CONFIG_HOME/clangd/config.yaml` by bootstrap.sh):
--     CompileFlags:
--       Compiler: /usr/bin/g++
--       Add: [-std=c++17, -Wall, -Wextra]
-- Project-level overrides beat the global file, so to match a
-- Makefile's `-std=c++11 -Wall` for one assignment, drop a `.clangd`
-- in that project's root with the desired `CompileFlags.Add`.

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      local clangd = opts.servers.clangd
      if not clangd then
        -- Extra not yet merged (should not happen with lazyvim.json),
        -- but keep a sane fallback so LSP still starts.
        clangd = { cmd = { "clangd" } }
        opts.servers.clangd = clangd
      end
      if not clangd.cmd or #clangd.cmd == 0 then
        clangd.cmd = { "clangd" }
      end

      local function has(flag)
        return vim.tbl_contains(clangd.cmd, flag)
      end

      -- clangd 23 rejects the bare `--function-arg-placeholders`.
      for i, flag in ipairs(clangd.cmd) do
        if flag == "--function-arg-placeholders" then
          clangd.cmd[i] = "--function-arg-placeholders=true"
        end
      end

      -- Whitelist GCC drivers for system-include extraction. The
      -- compiler itself is selected via clangd/config.yaml
      -- (Compiler: /usr/bin/g++), so the fallback command and
      -- extracted includes both come from g++.
      local qd = "--query-driver=/usr/bin/**/g++,/usr/bin/**/g++-*,/usr/bin/**/gcc*"
      if not has(qd) and vim.fn.executable("/usr/bin/g++") == 1 then
        table.insert(clangd.cmd, qd)
      end
      if not has("--enable-config") then
        table.insert(clangd.cmd, "--enable-config")
      end
      -- Keep background indexing for larger projects, but low priority
      -- so SSH responsiveness is not starved.
      if not has("--background-index-priority=low") then
        table.insert(clangd.cmd, "--background-index-priority=low")
      end
      if not has("--offset-encoding=utf-16") and not has("--offset-encoding=utf-8") then
        table.insert(clangd.cmd, "--offset-encoding=utf-16")
      end
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "clangd" } },
  },
}
