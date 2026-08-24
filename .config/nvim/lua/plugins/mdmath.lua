return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter").install({ "markdown", "markdown_inline", "latex" })
    end,
  },
  {
    "Thiago4532/mdmath.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    build = ":MdMath build",
    opts = {
      filetypes = { "markdown" },
    },
  },
}
