-- nvim-treesitter: API nueva (branch main). master está archivado desde 2025.
-- Ver: https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = function()
    local ok, ts = pcall(require, "nvim-treesitter")
    if ok and type(ts.update) == "function" then ts.update({ summary = false }) end
  end,
  event = { "BufReadPost", "BufNewFile" },
  lazy = false,
  config = function()
    local parsers = {
      "go", "python", "lua", "bash", "yaml", "json", "hcl", "terraform",
      "dockerfile", "markdown", "markdown_inline", "javascript", "typescript",
      "toml", "vim", "vimdoc", "regex",
    }

    require("nvim-treesitter").install(parsers)

    -- Activar highlight + indent por filetype (API main)
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local buf = args.buf
        local ft = vim.bo[buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if lang and pcall(vim.treesitter.start, buf, lang) then
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
