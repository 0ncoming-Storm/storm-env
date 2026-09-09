-- lua/plugins/remote.lua
return {
  -- 1. Disable animations and floating UI components that cause SSH lag
  { "folke/noice.nvim", enabled = false },
  { "akinsho/bufferline.nvim", enabled = false },
  { "folke/flash.nvim", enabled = false },
  { "echasnovski/mini.animate", enabled = false },

  -- 2. Keep Treesitter lightweight for remote typing
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      indent = { enable = false },
    },
  },

  -- 3. Prevent LSP linters from running while actively typing
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        update_in_insert = false,
      },
    },
  },
}
