require('nvim-treesitter.configs').setup({
  prefer_git = true, -- Avoids downloading release tarballs requiring tree-sitter CLI
  compilers = { "gcc", "clang", "cc" },
  sync_install = false,
  auto_install = true,
  highlight = { enable = true },
})
