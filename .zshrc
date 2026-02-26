# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
# Nota: Powerlevel10k usaba esto, Starship es rápido por defecto, 
# pero mantenemos la lógica de cache para plugins pesados.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE ENTORNO & PATHS
# ------------------------------------------------------------------------------
typeset -gU path # Evita duplicados en el PATH

# Configuraciones específicas para macOS (Jorge Ochoa)
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLOUDSDK_PYTHON="python3"
    export NVM_DIR="$HOME/.nvm"
    export ANDROID_HOME=$HOME/Library/Android/sdk
    export GOPATH=$HOME/go
    
    # Paths específicos de tu Mac
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
        /opt/homebrew/bin # Soporte para Apple Silicon
    )
    
    # Path para opencode
    export PATH="/Users/jorgeochoa/.opencode/bin:$PATH"
fi

# Path general para herramientas locales
export PATH="$HOME/.local/bin:$PATH"

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS MODERNAS
# ------------------------------------------------------------------------------
# Starship: El prompt ultra rápido
eval "$(starship init zsh)"

# Zoxide: El reemplazo inteligente de 'cd'
if command -v zoxide > /dev/null; then
    eval "$(zoxide init zsh)"
fi

# ------------------------------------------------------------------------------
# 4. CARGA DIFERIDA (LAZY LOADING) - OPTIMIZACIÓN DE VELOCIDAD
# ------------------------------------------------------------------------------
# Estas funciones evitan que la terminal tarde en abrir cargando SDKs pesados.

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

# JEnv (Java Version Manager)
jenv() {
    unset -f jenv
    if command -v jenv > /dev/null; then
        eval "$(jenv init -)"
        jenv "$@"
    fi
}

# NVM (Node Version Manager)
nvm() {
    unset -f nvm node npm npx
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # Linux fallback
    nvm "$@"
}
node() { nvm >/dev/null; node "$@" }
npm() { nvm >/dev/null; npm "$@" }
npx() { nvm >/dev/null; npx "$@" }

# ------------------------------------------------------------------------------
# 5. PLUGINS & COMPLETIONS
# ------------------------------------------------------------------------------
# Intentar cargar plugins desde rutas estándar de Ubuntu o Homebrew
PLUGIN_DIR_UBUNTU="/usr/share"
PLUGIN_DIR_MAC="/opt/homebrew/share"

# Autosuggestions
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

# Inicializar sistema de completado
autoload -Uz compinit && compinit -C
autoload -Uz bashcompinit && bashcompinit

# Terraform completion
if command -v terraform > /dev/null; then
    complete -o nospace -C $(which terraform) terraform
fi

# FZF Integration
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# ------------------------------------------------------------------------------
# 6. ALIASES (FUSIÓN MAESTRA)
# ------------------------------------------------------------------------------
# Navegación con Eza (si está instalado)
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

# Git (Tus favoritos + nuevos)
alias gs="git status -sb"
alias ga="git add ."
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --all"
alias gcb='git branch -a | fzf | xargs git checkout'

# Python (Productividad)
alias py='python3'
alias venv='python3 -m venv venv'
alias va='source venv/bin/activate'

# Sincronización de Dotfiles
alias dots='cd ~/dotfiles && git add . && git commit -m "Update dots: $(date)" && git push && cd -'

# ------------------------------------------------------------------------------
# 7. CONFIGURACIÓN DE HISTORIAL & OPCIONES
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

setopt NO_HUP AUTO_NAME_DIRS INC_APPEND_HISTORY SHARE_HISTORY
setopt HIST_IGNORE_DUPS HIST_REDUCE_BLANKS HIST_FIND_NO_DUPS

# Carga de entornos locales si existen
[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
