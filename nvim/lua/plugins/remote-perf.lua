-- nvim/lua/plugins/remote-perf.lua
return {
  -- 1. Disable network-heavy and animation plugins over SSH
  { "folke/noice.nvim", enabled = false },          -- Removes floating popups and heavy UI overlays
  { "akinsho/bufferline.nvim", enabled = false },   -- Uses native tabline; saves statusline redraw lag
  { "folke/flash.nvim", enabled = false },          -- Prevents screen-flicker highlighting over SSH
  { "theme-hotreload", enabled = false },           -- Stop background filesystem watching for themes

  -- 2. Keep Treesitter fast and snappy
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      indent = { enable = false }, -- Disable async indenting (major cause of typing latency)
    },
  },

  -- 3. Optimize LSP (clangd, pyright) for low-latency typing
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        update_in_insert = false, -- Don't run linters while actively typing
      },
    },
  },

  -- 4. Disable theme bloat (keep only one main theme like gruvbox or tokyonight)
  { "aether", enabled = false },
  { "hackerman.nvim", enabled = false },
  { "vantablack.nvim", enabled = false },
  { "white.nvim", enabled = false },
  { "everforest-nvim", enabled = false },
  { "flexoki-neovim", enabled = false },
  { "miasma.nvim", enabled = false },
  { "kanagawa.nvim", enabled = false },
  { "ashen.nvim", enabled = false },
  { "matteblack.nvim", enabled = false },
  { "ethereal.nvim", enabled = false },
  { "monokai-pro.nvim", enabled = false },
  { "nightfox.nvim", enabled = false },
  { "bamboo.nvim", enabled = false },
  { "catppuccin", enabled = false },
  { "retro-82.nvim", enabled = false },
  { "lumon.nvim", enabled = false },
  { "rose-pine", enabled = false },
}
