return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    ensure_installed = {
      "go", "python", "lua", "bash", "yaml", "json", "hcl", "terraform",
      "dockerfile", "markdown", "markdown_inline", "javascript", "typescript",
      "toml", "vim", "vimdoc", "regex",
    },
    highlight = { enable = true },
    indent = { enable = true },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
