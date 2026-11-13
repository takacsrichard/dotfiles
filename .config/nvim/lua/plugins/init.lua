return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  {
    "jpalardy/vim-slime",
    lazy = false,
    init = function()
      vim.g.slime_target = "tmux"
      vim.g.slime_bracketed_paste = 1
      vim.g.slime_no_mappings = 1
    end,
    config = function()
      local map = vim.keymap.set
      map("n", "<leader>sc", "<Plug>SlimeConfig", { desc = "slime: pick tmux pane" })
      map("n", "<leader>s", "<Plug>SlimeMotionSend", { desc = "slime: send motion" })
      map("x", "<leader>s", "<Plug>SlimeRegionSend", { desc = "slime: send selection" })
      map("n", "<leader>ss", "<Plug>SlimeLineSend", { desc = "slime: send line" })
      map("n", "<leader>sp", "<Plug>SlimeParagraphSend", { desc = "slime: send paragraph" })
    end,
  },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
