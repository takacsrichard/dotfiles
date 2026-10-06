require("config.lazy")

vim.opt.number = true
vim.opt.relativenumber = true

-- show relative number (blank on cursor line) plus the absolute number on every line,
-- each padded to a fixed width so the column doesn't jitter between single/double digits
vim.opt.statuscolumn = "%s%=%{printf('%4d ', v:lnum)}%{v:relnum == 0 ? '     ' : printf('%4d ', v:relnum)}"

vim.opt.whichwrap:append("<,>,h,l")

vim.opt.clipboard = "unnamedplus"

vim.keymap.set("n", "+", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute path of current file" })

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { buffer = true, nowait = true, desc = "Exit terminal mode" })
  end,
})

