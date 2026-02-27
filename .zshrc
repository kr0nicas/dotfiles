# ------------------------------------------------------------------------------
# 0. DIAGNÓSTICO DE CARGA (SRE-DEBUG)
# ------------------------------------------------------------------------------
alias sre-debug='echo "✅ Entorno Cargado | OS: $OSTYPE | User: $USER | PATH: $PATH"'

# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. CONFIGURACIÓN MAESTRA DE PATHS (RECUPERACIÓN DE BINARIOS)
# ------------------------------------------------------------------------------
typeset -gU path # Evita duplicados en el PATH

# Directorios base para Linux y Mac
path=(
    $HOME/.local/bin
    $HOME/bin
    $HOME/.krew/bin
    $HOME/go/bin          # Binarios de Go (Global)
    /usr/local/bin
    /usr/local/sbin
    /usr/bin
    /usr/sbin
    /bin
    /sbin
    /snap/bin
    $path
)

# Recuperación específica de Google Cloud SDK
if [ -d "$HOME/google-cloud-sdk" ]; then
    path=($HOME/google-cloud-sdk/bin $path)
fi

export PATH
export GOPATH="$HOME/go"   # Definición de GOPATH para compilaciones

# Configuración específica para macOS (Homebrew & Co.)
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLOUDSDK_PYTHON="python3"
    export NVM_DIR="$HOME/.nvm"
    export ANDROID_HOME="$HOME/Library/Android/sdk"

    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
fi

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS
# ------------------------------------------------------------------------------
command -v starship > /dev/null && eval "$(starship init zsh)"
command -v zoxide > /dev/null && eval "$(zoxide init zsh)"

# ------------------------------------------------------------------------------
# 4. CARGA DIFERIDA (LAZY LOADING) - OPTIMIZADO PARA SRE
# ------------------------------------------------------------------------------

# Función interna para cargar el SDK de Google Cloud
_load_gcloud_sdk() {
    unset -f gcloud gsutil bq 2>/dev/null
    
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ ! -d "$GCLOUD_PATH" ] && GCLOUD_PATH="/usr/lib/google-cloud-sdk"
    
    if [ -f "$GCLOUD_PATH/path.zsh.inc" ]; then
        source "$GCLOUD_PATH/path.zsh.inc"
        source "$GCLOUD_PATH/completion.zsh.inc" 2>/dev/null
    fi
}

# Disparadores individuales para GCP
gcloud() { _load_gcloud_sdk; command gcloud "$@" }
gsutil() { _load_gcloud_sdk; command gsutil "$@" }
bq()     { _load_gcloud_sdk; command bq "$@" }

# Lazy load para NVM (Node Version Manager)
nvm() {
    unset -f nvm node npm npx 2>/dev/null
    export NVM_DIR="$HOME/.nvm"
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm "$@"
}

# ------------------------------------------------------------------------------
# 5. PLUGINS & COMPLETIONS
# ------------------------------------------------------------------------------
PLUGIN_DIR_UBUNTU="/usr/share"
PLUGIN_DIR_MAC="/opt/homebrew/share"

if [ -d "$PLUGIN_DIR_MAC" ]; then
    [[ -f "$PLUGIN_DIR_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$PLUGIN_DIR_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$PLUGIN_DIR_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$PLUGIN_DIR_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh"
else
    [[ -f "$PLUGIN_DIR_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$PLUGIN_DIR_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    [[ -f "$PLUGIN_DIR_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$PLUGIN_DIR_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# ------------------------------------------------------------------------------
# 6. ALIASES (PRODUCTIVIDAD SRE & COMPATIBILIDAD)
# ------------------------------------------------------------------------------
# Python & Go
alias python='python3'
alias pip='pip3'
alias g='go'
alias grun='go run'
alias gbuild='go build'

# VS Code (Atajos rápidos)
alias c='code .'
alias v='code' # v para visual studio code

if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
else
    alias ll="ls -lAh"
fi

# Gestión de Servicios
alias sc='sudo systemctl'
alias sl='sudo journalctl -u'
alias st='sudo systemctl status'
alias claw-log='sl openclaw -f'
alias gateway-log='sl openclaw-gateway -f'
alias claw-restart='sc restart openclaw openclaw-gateway'

# Git & Navegación
alias gs="git status -sb"
alias gb="git branch -a | fzf --height 40% --reverse --info=inline | sed 's/.* //;s/remotes\/origin\///' | xargs git checkout"
alias gpl="git pull --rebase"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'
alias dots='cd "$DOTFILES" && git add . && git commit -m "Update dots: $(date)" && git push && cd -'

# ------------------------------------------------------------------------------
# 7. HISTORIAL & ESTABILIDAD
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD SHARE_HISTORY INC_APPEND_HISTORY NO_HUP

# Carga de entorno (Aquí es donde Edwin lee las llaves de Anthropic/Gemini)
[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"

# Variable para Anthropic (Opcional si prefieres tenerla en .zshrc en lugar de .env)
# export ANTHROPIC_API_KEY="tu_llave_aqui"
