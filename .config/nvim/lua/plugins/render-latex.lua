return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    main = "nvim-treesitter.configs",
    opts = {
      ensure_installed = { "markdown", "markdown_inline", "latex" },
      highlight = { enable = true },
    },
  },
  {
    "techwizrd/render-latex.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {},
  },
}
