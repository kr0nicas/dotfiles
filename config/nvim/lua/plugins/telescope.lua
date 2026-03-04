return {
  "nvim-telescope/telescope.nvim",
  branch = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  keys = {
    { "<C-p>", "<cmd>Telescope find_files<CR>", desc = "Buscar archivos" },
    { "<Leader>f", "<cmd>Telescope live_grep<CR>", desc = "Buscar texto (rg)" },
    { "<Leader>F", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Buscar en buffer" },
    { "<Leader>bb", "<cmd>Telescope buffers<CR>", desc = "Lista de buffers" },
    { "<Leader>gc", "<cmd>Telescope git_commits<CR>", desc = "Git commits" },
    { "<Leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { height = 0.65 },
      },
    })
    telescope.load_extension("fzf")
  end,
}
