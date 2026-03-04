return {
  "catppuccin/nvim",
  name = "catppuccin",
  lazy = false,
  priority = 1000,
  opts = {
    flavour = "mocha",
    integrations = {
      gitsigns = true,
      treesitter = true,
      telescope = { enabled = true },
      mason = true,
      native_lsp = { enabled = true },
      mini = { enabled = true },
    },
  },
  config = function(_, opts)
    require("catppuccin").setup(opts)
    vim.cmd.colorscheme("catppuccin")
  end,
}
