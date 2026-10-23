vim.opt_local.spell = true
vim.opt_local.spelllang = { "en_us" }

-- "ű" inserts $$ with cursor in between; use <C-v>ű for a literal ű
vim.keymap.set("i", "ű", "$$<Left>", { buffer = true })
