# --- 1. PLUGINS DE SISTEMA ---
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- 2. INICIALIZACIÓN DE HERRAMIENTAS ---
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# --- 3. ALIASES DE PRODUCTIVIDAD (PYTHON & SISTEMA) ---

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

# --- 4. CONFIGURACIÓN DE HISTORIAL ---
HISTSIZE=5000
SAVEHIST=5000
setopt SHARE_HISTORY
