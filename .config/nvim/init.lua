require("config.lazy")

vim.opt.whichwrap:append("<,>,h,l")

vim.opt.clipboard = "unnamedplus"

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = true, nowait = true, desc = "Exit terminal mode" })
  end,
})

