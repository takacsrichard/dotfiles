return {
  {
    "neovim/nvim-lspconfig",
    config = function()
      -- pass cmp capabilities to all LSP servers globally
      vim.lsp.config("*", {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
      })

      vim.lsp.enable("pyright")
      vim.lsp.enable("tinymist")
    end,
  },
}
