" ==============================================================================
" VIM CONFIG SRE 2026 - Jorge Ochoa (kr0nicas)
" ==============================================================================

" 1. CONFIGURACIÓN VISUAL
syntax on                   " Habilita resaltado de sintaxis
set number                  " Muestra números de línea
set relativenumber          " Números relativos para saltos rápidos (SRE Pro)
set cursorline              " Resalta la línea actual
set showcmd                 " Muestra comandos incompletos
set laststatus=2            " Siempre muestra la barra de estado

" 2. COMPORTAMIENTO Y EDICIÓN
set tabstop=4               " Tabulaciones de 4 espacios
set shiftwidth=4
set expandtab               " Convierte tabs en espacios
set autoindent              " Indentación automática
set mouse=a                 " Habilita el ratón en todos los modos
set clipboard=unnamedplus   " Usa el portapapeles del sistema si está disponible
set hidden                  " Permite cambiar de buffer sin guardar

" 3. BÚSQUEDA
set hlsearch                " Resalta las búsquedas
set incsearch               " Búsqueda incremental
set ignorecase              " Ignora mayúsculas al buscar
set smartcase               " ...a menos que se use una mayúscula

" 4. PERFORMANCE Y BACKUPS
set nobackup                " Evita archivos temporales molestos
set nowritebackup
set noswapfile
set updatetime=300          " Mejora la respuesta de plugins
set shortmess+=c            " No muestra mensajes innecesarios en el completado

" 5. ATAJOS RÁPIDOS
let mapleader = " "         " Espacio como tecla líder
nnoremap <Leader>w :w<CR>   " Espacio + w para guardar
nnoremap <Leader>q :q<CR>   " Espacio + q para salir

" Moverse entre paneles con CTRL + Dirección
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
