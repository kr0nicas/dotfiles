  1 │ " ==============================================================================
   2 │ " VIMRC SRE 2026 - Jorge Ochoa (kr0nicas)
   3 │ " ==============================================================================
   4 │ " Gestor de plugins: vim-plug
   5 │ " Instalar: curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
   6 │ "   https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
   7 │ " Activar plugins: :PlugInstall
   8 │ " ==============================================================================
   9 │
  10 │ " ------------------------------------------------------------------------------
  11 │ " 0. DETECCIÓN DE SISTEMA
  12 │ " ------------------------------------------------------------------------------
  13 │ let g:is_mac = has('macunix')
  14 │ let g:is_linux = has('unix') && !has('macunix')
  15 │
  16 │ " ------------------------------------------------------------------------------
  17 │ " 1. PLUGINS (VIM-PLUG)
  18 │ " ------------------------------------------------------------------------------
  19 │ call plug#begin('~/.vim/plugged')
  20 │
  21 │ " Navegación y búsqueda
  22 │ Plug 'junegunn/fzf',                { 'do': { -> fzf#install() } }
  23 │ Plug 'junegunn/fzf.vim'             " :Files, :Rg, :Lines, :Buffers
  24 │
  25 │ " Git
  26 │ Plug 'airblade/vim-gitgutter'       " Signos +/~/- en el gutter de git
  27 │ Plug 'tpope/vim-fugitive'           " :Git status, :Git blame, etc.
  28 │
  29 │ " Edición inteligente
  30 │ Plug 'tpope/vim-surround'           " cs'\" para cambiar comillas, ds( para borrar
  31 │ Plug 'tpope/vim-commentary'         " gcc para comentar línea, gc en visual
  32 │ Plug 'jiangmiao/auto-pairs'         " Cierra () [] {} '' automáticamente
  33 │
  34 │ " Sintaxis y lenguajes SRE
  35 │ Plug 'dense-analysis/ale'           " Linter async (yaml, json, go, python, sh)
  36 │ Plug 'pearofducks/ansible-vim'      " Sintaxis Ansible/YAML mejorada
  37 │ Plug 'hashivim/vim-terraform'       " Sintaxis Terraform/HCL
  38 │ Plug 'fatih/vim-go',                { 'for': 'go' }
  39 │
  40 │ " Estética
  41 │ Plug 'catppuccin/vim',              { 'as': 'catppuccin' }  " Misma paleta que starship/tmux
  42 │ Plug 'itchyny/lightline.vim'        " Statusline ligera y configurable
  43 │
  44 │ call plug#end()
  45 │
  46 │ " ------------------------------------------------------------------------------
  47 │ " 2. CONFIGURACIÓN VISUAL
  48 │ " ------------------------------------------------------------------------------
  49 │ syntax on
  50 │ set termguicolors
  51 │ set background=dark
  52 │ silent! colorscheme catppuccin_mocha   " Carga catppuccin, no falla si no está
  53 │
  54 │ set number
  55 │ set relativenumber
  56 │ set cursorline
  57 │ set showcmd
  58 │ set laststatus=2
  59 │ set title
  60 │ set signcolumn=yes                  " Siempre visible para gitgutter y ale
  61 │ set scrolloff=8                     " Mantiene 8 líneas de contexto al hacer scroll
  62 │ set sidescrolloff=8
  63 │ set nowrap                          " Sin saltos de línea automáticos
  64 │ set colorcolumn=100                 " Guía visual de longitud de línea
  65 │ set list                            " Muestra caracteres invisibles
  66 │ set listchars=tab:→\ ,trail:·,nbsp:␣
  67 │
  68 │ " Números relativos en normal, absolutos en insert (más natural)
  69 │ augroup SmartNumbers
  70 │     autocmd!
  71 │     autocmd InsertEnter * set norelativenumber
  72 │     autocmd InsertLeave * set relativenumber
  73 │ augroup END
  74 │
  75 │ " ------------------------------------------------------------------------------
  76 │ " 3. COMPORTAMIENTO Y EDICIÓN
  77 │ " ------------------------------------------------------------------------------
  78 │ set tabstop=4
  79 │ set shiftwidth=4
  80 │ set softtabstop=4
  81 │ set expandtab
  82 │ set autoindent
  83 │ set smartindent
  84 │ set mouse=a
  85 │ set hidden                          " Cambia de buffer sin guardar
  86 │ set splitright                      " Splits verticales a la derecha
  87 │ set splitbelow                      " Splits horizontales abajo
  88 │ set confirm                         " Pregunta antes de cerrar con cambios
  89 │ set backspace=indent,eol,start      " Backspace funciona como se espera
  90 │
  91 │ " Portapapeles: detecta Mac vs Linux
  92 │ if g:is_mac
  93 │     set clipboard=unnamed
  94 │ else
  95 │     set clipboard=unnamedplus
  96 │ endif
  97 │
  98 │ " ------------------------------------------------------------------------------
  99 │ " 4. BÚSQUEDA
 100 │ " ------------------------------------------------------------------------------
 101 │ set hlsearch
 102 │ set incsearch
 103 │ set ignorecase
 104 │ set smartcase
 105 │ set gdefault                        " Reemplaza todas las ocurrencias por defecto (%s/a/b en vez de %s/a/b/g)
 106 │
 107 │ " ------------------------------------------------------------------------------
 108 │ " 5. PERFORMANCE Y ESTABILIDAD
 109 │ " ------------------------------------------------------------------------------
 110 │ set nobackup
 111 │ set nowritebackup
 112 │ set noswapfile
 113 │ set undofile                        " Historial de undo persistente entre sesiones
 114 │ set undodir=~/.vim/undodir          " Directorio para archivos de undo
 115 │ set updatetime=100                  " Más rápido que 300 — mejora gitgutter
 116 │ set shortmess+=c
 117 │ set encoding=utf-8
 118 │ set fileencoding=utf-8
 119 │ set lazyredraw                      " No redibuja durante macros (más rápido)
 120 │ set ttyfast
 121 │
 122 │ " Crear directorio de undo si no existe
 123 │ if !isdirectory($HOME."/.vim/undodir")
 124 │     call mkdir($HOME."/.vim/undodir", "p", 0700)
 125 │ endif
 126 │
 127 │ " ------------------------------------------------------------------------------
 128 │ " 6. ATAJOS (LEADER = ESPACIO)
 129 │ " ------------------------------------------------------------------------------
 130 │ let mapleader = " "
 131 │
 132 │ " Archivos
 133 │ nnoremap <Leader>w :w<CR>
 134 │ nnoremap <Leader>q :q<CR>
 135 │ nnoremap <Leader>x :x<CR>
 136 │ nnoremap <Leader>e :e <C-r>=expand('%:p:h')<CR>/   " Abrir archivo relativo al actual
 137 │
 138 │ " Buffers
 139 │ nnoremap <Leader>n  :bn<CR>
 140 │ nnoremap <Leader>p  :bp<CR>
 141 │ nnoremap <Leader>d  :bd<CR>
 142 │ nnoremap <Leader>bb :Buffers<CR>    " Lista de buffers con fzf
 143 │
 144 │ " Navegación entre paneles con CTRL
 145 │ nnoremap <C-h> <C-w>h
 146 │ nnoremap <C-j> <C-w>j
 147 │ nnoremap <C-k> <C-w>k
 148 │ nnoremap <C-l> <C-w>l
 149 │
 150 │ " Resize de paneles con Leader + flechas
 151 │ nnoremap <Leader><Up>    :resize +5<CR>
 152 │ nnoremap <Leader><Down>  :resize -5<CR>
 153 │ nnoremap <Leader><Left>  :vertical resize -5<CR>
 154 │ nnoremap <Leader><Right> :vertical resize +5<CR>
 155 │
 156 │ " Búsqueda
 157 │ nnoremap <Leader>/  :nohlsearch<CR>  " Limpia el highlight de búsqueda
 158 │
 159 │ " FZF
 160 │ nnoremap <C-p>      :Files<CR>
 161 │ nnoremap <Leader>f  :Rg<CR>          " Busca texto en proyecto (requiere ripgrep)
 162 │ nnoremap <Leader>F  :Lines<CR>       " Busca en buffers abiertos
 163 │ nnoremap <Leader>gc :Commits<CR>     " Historial de commits con fzf
 164 │
 165 │ " Git (fugitive)
 166 │ nnoremap <Leader>gs :Git<CR>
 167 │ nnoremap <Leader>gb :Git blame<CR>
 168 │ nnoremap <Leader>gd :Gdiffsplit<CR>
 169 │ nnoremap <Leader>gl :Git log --oneline<CR>
 170 │
 171 │ " Mover líneas con Alt+j/k en cualquier modo
 172 │ nnoremap <A-j> :m .+1<CR>==
 173 │ nnoremap <A-k> :m .-2<CR>==
 174 │ vnoremap <A-j> :m '>+1<CR>gv=gv
 175 │ vnoremap <A-k> :m '<-2<CR>gv=gv
 176 │
 177 │ " ------------------------------------------------------------------------------
 178 │ " 7. FILETYPES SRE
 179 │ " ------------------------------------------------------------------------------
 180 │ augroup SRE_FILETYPES
 181 │     autocmd!
 182 │
 183 │     " YAML: Kubernetes, Ansible, Docker Compose — 2 espacios
 184 │     autocmd FileType yaml,yml setlocal ts=2 sts=2 sw=2 expandtab
 185 │
 186 │     " JSON: 2 espacios
 187 │     autocmd FileType json setlocal ts=2 sts=2 sw=2 expandtab
 188 │
 189 │     " Go: tabs reales (estándar Google)
 190 │     autocmd FileType go setlocal ts=4 sw=4 noexpandtab
 191 │
 192 │     " Shell/Bash: 2 espacios
 193 │     autocmd FileType sh,bash,zsh setlocal ts=2 sts=2 sw=2 expandtab
 194 │
 195 │     " Terraform/HCL: 2 espacios
 196 │     autocmd FileType terraform,hcl setlocal ts=2 sts=2 sw=2 expandtab
 197 │
 198 │     " Dockerfile
 199 │     autocmd FileType dockerfile setlocal ts=4 sts=4 sw=4 expandtab
 200 │
 201 │     " Markdown: wrap activo para redactar
 202 │     autocmd FileType markdown setlocal wrap linebreak
 203 │
 204 │     " Limpiar espacios al final — solo en archivos de texto (no binarios)
 205 │     autocmd BufWritePre *.py,*.go,*.js,*.ts,*.yaml,*.yml,*.json,*.sh,*.tf,*.md
 206 │         \ :%s/\s\+$//e
 207 │
 208 │ augroup END
 209 │
 210 │ " ------------------------------------------------------------------------------
 211 │ " 8. CONFIGURACIÓN DE PLUGINS
 212 │ " ------------------------------------------------------------------------------
 213 │
 214 │ " — ALE (Linter) —
 215 │ let g:ale_linters = {
 216 │ \   'python':    ['flake8', 'pylint'],
 217 │ \   'go':        ['golint', 'govet'],
 218 │ \   'yaml':      ['yamllint'],
 219 │ \   'json':      ['jsonlint'],
 220 │ \   'sh':        ['shellcheck'],
 221 │ \   'terraform': ['tflint'],
 222 │ \}
 223 │ let g:ale_fixers = {
 224 │ \   '*':      ['remove_trailing_lines', 'trim_whitespace'],
 225 │ \   'python': ['black'],
 226 │ \   'go':     ['gofmt'],
 227 │ \   'json':   ['jq'],
 228 │ \}
 229 │ let g:ale_fix_on_save       = 1
 230 │ let g:ale_sign_error        = ''
 231 │ let g:ale_sign_warning      = ''
 232 │ let g:ale_echo_msg_format   = '[%linter%] %s [%severity%]'
 233 │
 234 │ " — GitGutter —
 235 │ let g:gitgutter_sign_added    = '▎'
 236 │ let g:gitgutter_sign_modified = '▎'
 237 │ let g:gitgutter_sign_removed  = '▎'
 238 │ highlight GitGutterAdd    guifg=#a6e3a1
 239 │ highlight GitGutterChange guifg=#f9e2af
 240 │ highlight GitGutterDelete guifg=#f38ba8
 241 │
 242 │ " — Lightline (Statusline) — Catppuccin Mocha
 243 │ let g:lightline = {
 244 │ \   'colorscheme': 'catppuccin_mocha',
 245 │ \   'active': {
 246 │ \     'left':  [['mode', 'paste'], ['gitbranch', 'readonly', 'filename', 'modified']],
 247 │ \     'right': [['lineinfo'], ['percent'], ['filetype', 'fileencoding'], ['linter_errors', 'linter_warnings']]
 248 │ \   },
 249 │ \   'component_function': {
 250 │ \     'gitbranch': 'FugitiveHead',
 251 │ \   },
 252 │ \}
 253 │
 254 │ " — vim-go —
 255 │ let g:go_fmt_command        = "goimports"
 256 │ let g:go_highlight_types    = 1
 257 │ let g:go_highlight_fields   = 1
 258 │ let g:go_highlight_functions = 1
 259 │
 260 │ " — vim-terraform —
 261 │ let g:terraform_fmt_on_save = 1
 262 │ let g:terraform_align       = 1
 263 │
 264 │ " — FZF —
 265 │ let g:fzf_layout = { 'down': '~35%' }
 266 │ let g:fzf_colors = {
 267 │ \   'fg':      ['fg', 'Normal'],
 268 │ \   'bg':      ['bg', 'Normal'],
 269 │ \   'hl':      ['fg', 'Comment'],
 270 │ \   'fg+':     ['fg', 'CursorLine'],
 271 │ \   'bg+':     ['bg', 'CursorLine'],
 272 │ \   'hl+':     ['fg', 'Statement'],
 273 │ \   'info':    ['fg', 'PreProc'],
 274 │ \   'border':  ['fg', 'Ignore'],
 275 │ \   'prompt':  ['fg', 'Conditional'],
 276 │ \   'pointer': ['fg', 'Exception'],
 277 │ \   'marker':  ['fg', 'Keyword'],
 278 │ \   'spinner': ['fg', 'Label'],
 279 │ \   'header':  ['fg', 'Comment'],
 280 │ \}
