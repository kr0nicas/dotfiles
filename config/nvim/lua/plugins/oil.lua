return {
  "stevearc/oil.nvim",
  lazy = false,
  keys = {
    { "-", "<cmd>Oil<CR>", desc = "Abrir file explorer" },
  },
  opts = {
    default_file_explorer = true,
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["q"] = "actions.close",
      ["<C-s>"] = false, -- no split accidental
    },
  },
}
