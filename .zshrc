export PATH="$HOME/.local/bin:$PATH"
# Colorear el comando 'ls' (eza) con la misma paleta
export EZA_COLORS="di=38;5;111:ln=38;5;115:so=38;5;109:pi=38;5;108:ex=38;5;121:bd=38;5;231:cd=38;5;231:su=0:sg=0:tw=0:ow=0"
# --- Detectar Sistema Operativo ---
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Configuración específica para macOS (MacBook)
    alias brew-up='brew update && brew upgrade'
    # El path de Homebrew suele ser diferente en Apple Silicon
    export PATH="/opt/homebrew/bin:$PATH"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Configuración específica para Linux (VPS)
    alias apt-up='sudo apt update && sudo apt upgrade -y'
fi

# --- 1. PLUGINS DE SISTEMA ---
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- 2. INICIALIZACIÓN DE HERRAMIENTAS ---
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# --- 3. ALIASES DE PRODUCTIVIDAD (PYTHON & SISTEMA) ---


# Buscar y cambiar de rama de git interactivamente
alias gcb='git branch -a | fzf | xargs git checkout'

# El reemplazo básico (con iconos y carpetas primero)
alias ls='eza --icons --group-directories-first'

# El "Listado Largo" (reemplaza a 'ls -lh')
# Muestra tamaño de archivos, permisos y cabeceras
alias ll='eza -lh --icons --group-directories-first'

# El "Listado Maestro" (reemplaza a 'ls -la')
# Muestra archivos ocultos y detalles de Git (si estás en un repo)
alias la='eza -lah --icons --git --group-directories-first'

# Extra: Ver carpetas como un árbol (reemplaza al comando 'tree')
alias lt='eza --tree --level=2 --icons'



# Atajos para Python (indispensables)
alias py='python3'
alias venv='python3 -m venv venv'
alias va='source venv/bin/activate'
alias pipir='pip install -r requirements.txt'

# Navegación y archivos con estilo (usando eza/bat si los instalaste)
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --git'
alias cat='batcat --paging=never'

# Docker (que mencionaste en tu stack)
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dcu='docker-compose up -d'
alias dcd='docker-compose down'

# Alias universal (Ubuntu llama al binario batcat, Mac lo llama bat)
if command -v batcat > /dev/null; then
  alias cat='batcat --paging=never'
  alias bat='batcat'
elif command -v bat > /dev/null; then
  alias cat='bat --paging=never'
fi

# Exportar tema por defecto
export BAT_THEME="Dracula"
# Buscar archivos y previsualizarlos con colores antes de abrirlos
alias fp='fzf --preview "batcat --color=always --style=numbers --line-range=:500 {}"'
# --- 4. CONFIGURACIÓN DE HISTORIAL ---
HISTSIZE=5000
SAVEHIST=5000
setopt SHARE_HISTORY
