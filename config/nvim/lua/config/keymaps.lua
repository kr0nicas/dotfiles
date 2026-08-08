-- =============================================================================
-- KEYMAPS — port de vimrc seccion 6
-- =============================================================================
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local map = vim.keymap.set

-- Archivos
map("n", "<Leader>w", "<cmd>w<CR>", { desc = "Guardar" })
map("n", "<Leader>q", "<cmd>q<CR>", { desc = "Salir" })
map("n", "<Leader>x", "<cmd>x<CR>", { desc = "Guardar y salir" })

-- Buffers
map("n", "<Leader>n", "<cmd>bn<CR>", { desc = "Buffer siguiente" })
map("n", "<Leader>p", "<cmd>bp<CR>", { desc = "Buffer anterior" })
map("n", "<Leader>d", "<cmd>bd<CR>", { desc = "Cerrar buffer" })

-- Navegacion entre paneles con CTRL: la define plugins/navigation.lua
-- (vim-tmux-navigator). No la redeclares aqui: keymaps.lua se carga despues de
-- config.lazy y pisaria los stubs de lazy, dejando el plugin sin cargar nunca.

-- Resize de paneles con Leader + flechas
map("n", "<Leader><Up>", "<cmd>resize +5<CR>")
map("n", "<Leader><Down>", "<cmd>resize -5<CR>")
map("n", "<Leader><Left>", "<cmd>vertical resize -5<CR>")
map("n", "<Leader><Right>", "<cmd>vertical resize +5<CR>")

-- Busqueda
map("n", "<Leader>/", "<cmd>nohlsearch<CR>", { desc = "Limpiar highlight" })

-- Git (fugitive)
map("n", "<Leader>gs", "<cmd>Git<CR>", { desc = "Git status" })
map("n", "<Leader>gb", "<cmd>Git blame<CR>", { desc = "Git blame" })
map("n", "<Leader>gd", "<cmd>Gdiffsplit<CR>", { desc = "Git diff" })
map("n", "<Leader>gl", "<cmd>Git log --oneline<CR>", { desc = "Git log" })

-- Mover lineas con Alt+j/k
map("n", "<A-j>", "<cmd>m .+1<CR>==")
map("n", "<A-k>", "<cmd>m .-2<CR>==")
map("v", "<A-j>", ":m '>+1<CR>gv=gv")
map("v", "<A-k>", ":m '<-2<CR>gv=gv")
