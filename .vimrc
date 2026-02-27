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
set termguicolors           " Soporte para colores de 24 bits
set title                   " Cambia el título de la terminal al nombre del archivo

" 2. COMPORTAMIENTO Y EDICIÓN
set tabstop=4               " Tabulaciones de 4 espacios por defecto
set shiftwidth=4
set expandtab               " Convierte tabs en espacios
set autoindent              " Indentación automática
set smartindent
set mouse=a                 " Habilita el ratón en todos los modos
set clipboard=unnamedplus   " Usa el portapapeles del sistema
set hidden                  " Permite cambiar de buffer sin guardar
set colorcolumn=100         " Guía visual para no escribir líneas eternas

" 3. BÚSQUEDA
set hlsearch                " Resalta las búsquedas
set incsearch               " Búsqueda incremental
set ignorecase              " Ignora mayúsculas al buscar
set smartcase               " ...a menos que se use una mayúscula

" 4. PERFORMANCE Y ESTABILIDAD
set nobackup                " Evita archivos temporales .swp
set nowritebackup
set noswapfile
set updatetime=300          " Mejora la respuesta de la interfaz
set shortmess+=c            " Menos verbosidad en el completado
set encoding=utf-8          " Codificación estándar

" 5. ATAJOS RÁPIDOS (LEADER = ESPACIO)
let mapleader = " "         " Espacio como tecla líder

" Operaciones de archivo
nnoremap <Leader>w :w<CR>
nnoremap <Leader>q :q<CR>
nnoremap <Leader>x :x<CR>

" Gestión de Buffers (Pestañas internas)
nnoremap <Leader>n :bn<CR>  " Siguiente archivo abierto
nnoremap <Leader>p :bp<CR>  " Anterior archivo abierto
nnoremap <Leader>d :bd<CR>  " Cerrar archivo actual sin salir de Vim

" Moverse entre paneles con CTRL + Dirección
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" 6. INTEGRACIÓN SRE (YAML, JSON, GO, PYTHON)
" Configuración específica por tipo de archivo
augroup SRE_FILETYPES
    autocmd!
    " YAML (Kubernetes/Ansible): Siempre 2 espacios
    autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
    " JSON: 2 espacios
    autocmd FileType json setlocal ts=2 sts=2 sw=2 expandtab
    " GO: Usar pestañas reales (estándar de Google)
    autocmd FileType go setlocal ts=4 sw=4 noexpandtab
    " Limpiar espacios en blanco al final de la línea al guardar
    autocmd BufWritePre * :%s/\s\+$//e
augroup END

" 7. INTEGRACIÓN CON FZF (Aprovechando tu fzf 0.66.0)
" Buscar archivos en el proyecto actual
nnoremap <C-p> :FZF<CR>
" Buscar texto dentro de los archivos abiertos
nnoremap <Leader>f :Lines<CR>
