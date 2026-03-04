return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    plugins = { spelling = { enabled = true } },
  },
  config = function(_, opts)
    local wk = require("which-key")
    wk.setup(opts)
    wk.add({
      { "<Leader>b", group = "buffers" },
      { "<Leader>c", group = "code" },
      { "<Leader>g", group = "git" },
      { "<Leader>h", group = "hunks" },
      { "<Leader>f", desc = "find (grep)" },
    })
  end,
}
