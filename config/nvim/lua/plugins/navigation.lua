-- Navegacion transparente entre splits de nvim y paneles de tmux.
-- Fuera de tmux el plugin degrada a <C-w>hjkl, asi que C-hjkl funciona igual
-- en una caja sin multiplexor.
return {
  {
    "christoomey/vim-tmux-navigator",
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
    },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Pane/split izquierda" },
      { "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Pane/split abajo" },
      { "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Pane/split arriba" },
      { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Pane/split derecha" },
    },
  },
}
