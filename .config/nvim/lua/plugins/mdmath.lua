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
    build = function()
      return require("mdmath.build").build_lazy()
    end,
    opts = {
      filetypes = { "markdown" },
    },
  },
  {
    "jbyuki/nabla.nvim",
    lazy = true,
    keys = {
      {
        "<leader>lt",
        function()
          local nabla = require("nabla")
          local mdmath = require("mdmath")
          if require("nabla").is_virt_enabled and nabla.is_virt_enabled() then
            nabla.disable_virt()
            mdmath.enable()
            vim.notify("LaTeX: mdmath (image)", vim.log.levels.INFO)
          else
            mdmath.disable()
            nabla.enable_virt()
            vim.notify("LaTeX: nabla (ASCII)", vim.log.levels.INFO)
          end
        end,
        desc = "Toggle LaTeX renderer (mdmath ↔ nabla)",
      },
    },
  },
}
