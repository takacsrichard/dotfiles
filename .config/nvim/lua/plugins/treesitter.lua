return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false,
  config = function()
    require("nvim-treesitter").install({
      "lua",
      "vim",
      "vimdoc",
      "query",
      "bash",
      "python",
      "nix",
      "markdown",
      "markdown_inline",
      "latex",
      "json",
      "yaml",
      "toml",
      "c",
      "cpp",
      "rust",
      "javascript",
      "typescript",
      "html",
      "css",
    })

    -- enable treesitter highlighting for any filetype with an installed parser
    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}
