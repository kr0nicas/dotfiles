-- =============================================================================
-- OPTIONS — port de vimrc secciones 2-5
-- =============================================================================
local opt = vim.opt

-- Visual
opt.termguicolors = true
opt.background = "dark"
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.showcmd = true
opt.laststatus = 2
opt.title = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false
opt.colorcolumn = "100"
opt.list = true
opt.listchars = { tab = "→ ", trail = "·", nbsp = "␣" }

-- Edicion
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.mouse = "a"
opt.splitright = true
opt.splitbelow = true
opt.confirm = true

-- Clipboard: detecta Mac vs Linux
if vim.fn.has("macunix") == 1 then
  opt.clipboard = "unnamed"
else
  opt.clipboard = "unnamedplus"
end

-- Busqueda
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.gdefault = true

-- Performance
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.updatetime = 100
opt.shortmess:append("c")
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
