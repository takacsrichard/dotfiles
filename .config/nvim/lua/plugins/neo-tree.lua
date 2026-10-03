return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  lazy = false,
  event = "VimEnter",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle Neo-tree" },
    { "<leader>f", "<cmd>Neotree reveal<cr>", desc = "Reveal file in Neo-tree" },
  },
  opts = {
    close_if_last_window = true,
    window = {
      position = "left",
      width = 30,
    },
    filesystem = {
      filtered_items = {
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
  },
  config = function(_, opts)
    require("neo-tree").setup(opts)
    vim.cmd("Neotree show")
  end,
}
