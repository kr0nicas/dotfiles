return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      -- El nombre del tema lleva flavour: catppuccin/nvim no expone un
      -- "catppuccin" a secas, solo catppuccin-{latte,frappe,macchiato,mocha}.
      -- Con el nombre corto lualine cae a `auto` en silencio y la barra deja
      -- de ir a juego con el resto del tema.
      theme = "catppuccin-mocha",
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { "filename" },
      lualine_x = { "encoding", "filetype" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  },
}
