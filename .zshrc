# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
# Mantiene la carga visual instantánea mientras se procesan los plugins.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE ENTORNO & PATHS (ESTABILIDAD SRE)
# ------------------------------------------------------------------------------
typeset -gU path # Evita duplicados en el PATH

# Path general para herramientas locales (Prioridad para evitar cuelgues)
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Configuraciones específicas para macOS (Jorge Ochoa)
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLOUDSDK_PYTHON="python3"
    export NVM_DIR="$HOME/.nvm"
    export ANDROID_HOME=$HOME/Library/Android/sdk
    export GOPATH=$HOME/go
    
    path=(
        $path
        $HOME/.krew/bin
        /usr/local/opt/openvpn/sbin
        /usr/local/opt/ruby/bin
        /usr/local/opt/mongodb-community/bin
        $HOME/.poetry/bin
        $HOME/.jenv/bin
        $ANDROID_HOME/cmdline-tools/latest/bin
        $ANDROID_HOME/platform-tools
        $GOPATH/bin
        $HOME/.opencode/bin
        /opt/homebrew/bin # Soporte Apple Silicon
    )
    # Binarios de opencode específicos
    export PATH="/Users/jorgeochoa/.opencode/bin:$PATH"
fi

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS (RUST POWERED)
# ------------------------------------------------------------------------------
# Starship: El prompt ultra rápido
if command -v starship > /dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide: El reemplazo inteligente de 'cd'
if command -v zoxide > /dev/null; then
    eval "$(zoxide init zsh)"
fi

# ------------------------------------------------------------------------------
# 4. CARGA DIFERIDA (LAZY LOADING) - VELOCIDAD MÁXIMA
# ------------------------------------------------------------------------------
# Google Cloud SDK
gcloud() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ -f "$GCLOUD_PATH/path.zsh.inc" ] && . "$GCLOUD_PATH/path.zsh.inc"
    [ -f "$GCLOUD_PATH/completion.zsh.inc" ] && . "$GCLOUD_PATH/completion.zsh.inc"
    gcloud "$@"
}
gsutil() { gcloud "$@"; gsutil "$@" }
bq() { gcloud "$@"; bq "$@" }

# NVM (Node Version Manager)
nvm() {
    unset -f nvm node npm npx
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm "$@"
}
node() { nvm >/dev/null; node "$@" }
npm() { nvm >/dev/null; npm "$@" }
npx() { nvm >/dev/null; npx "$@" }

# ------------------------------------------------------------------------------
# 5. PLUGINS & COMPLETIONS
# ------------------------------------------------------------------------------
PLUGIN_DIR_UBUNTU="/usr/share"
PLUGIN_DIR_MAC="/opt/homebrew/share"

# Autosuggestions (Optimizado para evitar lag en VPS)
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

if [ -f "$PLUGIN_DIR_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$PLUGIN_DIR_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -f "$PLUGIN_DIR_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$PLUGIN_DIR_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Syntax Highlighting
if [ -f "$PLUGIN_DIR_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$PLUGIN_DIR_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [ -f "$PLUGIN_DIR_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$PLUGIN_DIR_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

autoload -Uz compinit && compinit -C
autoload -Uz bashcompinit && bashcompinit

# Integración FZF (Historial y archivos)
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# ------------------------------------------------------------------------------
# 6. ALIASES (PRODUCTIVIDAD SRE)
# ------------------------------------------------------------------------------
# Navegación con Eza
if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons'
    alias lt='eza --tree --level=2 --icons'
else
    alias ll="ls -lAh"
fi

# Visualización con Bat
if command -v batcat > /dev/null; then
    alias cat='batcat --paging=never'
    alias bat='batcat'
elif command -v bat > /dev/null; then
    alias cat='bat --paging=never'
fi

# Homebrew Management (Solo Mac)
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias blist='cat ~/dotfiles/Brewfile' # Lista el contenido del archivo
    alias bcheck='brew bundle list --file=~/dotfiles/Brewfile' # Lista lo que brew reconoce
    alias bclean='brew bundle cleanup --file=~/dotfiles/Brewfile' # MUESTRA qué tienes instalado que NO está en el Brewfile
    alias bdump='brew bundle dump --force --file=~/dotfiles/Brewfile' # Actualiza el Brewfile con lo que tienes ahora
fi

# Git Aliases
alias gs="git status -sb"
alias ga="git add ."
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --all"
alias gcb='git branch -a | fzf | xargs git checkout'

# SSH & TMUX Workflow
# Selector maestro de servidores (Usa FZF para elegir del config)
alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'

# Función para conexión persistente
ssht() {
    ssh -t "$1" "tmux attach || tmux new"
}

# Python & Infra
alias py='python3'
alias venv='python3 -m venv venv'
alias va='source venv/bin/activate'
alias dots='cd ~/dotfiles && git add . && git commit -m "Update dots: $(date)" && git push && cd -'

# ------------------------------------------------------------------------------
# 7. CONFIGURACIÓN DE HISTORIAL & ESTABILIDAD
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# Fix para evitar desconexiones de VPS
export TMOUT=0              
setopt AUTO_CD              # Entrar a carpetas sin 'cd'
setopt NO_HUP               # Mantener procesos vivos
setopt INC_APPEND_HISTORY   
setopt SHARE_HISTORY 

# Carga de entornos locales (Edwin / Partnertech)
[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
