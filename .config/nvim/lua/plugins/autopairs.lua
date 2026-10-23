return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local npairs = require("nvim-autopairs")
      npairs.setup({})

      local Rule = require("nvim-autopairs.rule")
      local cond = require("nvim-autopairs.conds")

      -- only close $...$ when there isn't already an unclosed $ earlier on the line
      local function even_dollars_before(opts)
        return select(2, opts.line:sub(1, opts.col - 1):gsub("%$", "")) % 2 == 0
      end

      npairs.add_rules({
        Rule("$", "$", "typst")
          :with_pair(even_dollars_before)
          :with_move(cond.done()),
      })
    end,
  },
}
