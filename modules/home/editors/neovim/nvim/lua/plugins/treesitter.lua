---@type LazySpec
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua",
        "vim",
      },
    },
  },
  {
    "zebradil/tree-sitter-test_highlights",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "test_highlights" }, -- use :set filetype=test_highlights to activate
  },
  {
    "zebradil/tree-sitter-ytt_annotation",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    lazy = false,
  },
  {
    "zebradil/tree-sitter-queries",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      modules = {
        "yaml-lang",
      },
    },
  },
}
