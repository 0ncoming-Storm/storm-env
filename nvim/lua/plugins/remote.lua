-- lua/plugins/remote.lua
-- Latency tuning for editing over SSH.
return {
  -- 1. Disable floating UI components that cause SSH lag.
  --
  -- NOTE: mini.animate is deliberately NOT disabled here. It used to be, but
  -- against the old "echasnovski/mini.animate" repo path, which mini-animate.lua
  -- had already retired in favour of "nvim-mini/mini.animate" -- so the line was
  -- a no-op and the two files contradicted each other. mini-animate.lua is now
  -- the single source of truth for it. If you want animations off for speed,
  -- flip `enabled = false` there, not here.
  { "folke/noice.nvim", enabled = false },
  { "akinsho/bufferline.nvim", enabled = false },
  { "folke/flash.nvim", enabled = false },

  -- 2. Prevent LSP linters from running while actively typing
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        update_in_insert = false,
      },
    },
  },
}
