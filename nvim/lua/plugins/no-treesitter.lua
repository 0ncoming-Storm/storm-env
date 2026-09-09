return {
  -- 1. Disable nvim-treesitter completely
  {
    "nvim-treesitter/nvim-treesitter",
    enabled = false,
  },

  -- 2. Force standard Vim syntax highlighting on file load
  {
    "LazyVim/LazyVim",
    opts = function()
      vim.cmd("syntax on")
      vim.cmd("filetype plugin indent on")
    end,
  },
}
