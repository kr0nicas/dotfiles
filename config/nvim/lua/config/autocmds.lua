-- =============================================================================
-- AUTOCOMMANDS — port de vimrc seccion 7
-- =============================================================================
local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Numeros relativos en normal, absolutos en insert
local smart_numbers = augroup("SmartNumbers", { clear = true })
autocmd("InsertEnter", { group = smart_numbers, callback = function() vim.opt.relativenumber = false end })
autocmd("InsertLeave", { group = smart_numbers, callback = function() vim.opt.relativenumber = true end })

-- Filetypes SRE
local sre = augroup("SRE_FILETYPES", { clear = true })

autocmd("FileType", {
  group = sre,
  pattern = { "yaml", "yml", "json", "sh", "bash", "zsh", "terraform", "hcl" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.expandtab = true
  end,
})

autocmd("FileType", {
  group = sre,
  pattern = { "go" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = false
  end,
})

autocmd("FileType", {
  group = sre,
  pattern = { "dockerfile" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})

autocmd("FileType", {
  group = sre,
  pattern = { "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Limpiar espacios al final
autocmd("BufWritePre", {
  group = sre,
  pattern = { "*.py", "*.go", "*.js", "*.ts", "*.yaml", "*.yml", "*.json", "*.sh", "*.tf", "*.md" },
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[%s/\s\+$//e]])
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})
