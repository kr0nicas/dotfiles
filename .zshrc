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

path=(
    $HOME/.local/bin
    $HOME/bin
    $HOME/.krew/bin
    $HOME/go/bin          # Binarios de Go
    /usr/local/bin
    /usr/local/sbin
    /usr/bin
    /usr/sbin
    /bin
    /sbin
    /snap/bin             # Soporte para binarios de Ubuntu Snap
    $path
)

if [ -d "$HOME/google-cloud-sdk" ]; then
    path=($HOME/google-cloud-sdk/bin $path)
fi

export PATH
export GOPATH="$HOME/go"

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
# 4. CARGA DIFERIDA (LAZY LOADING) - FIX DEFINITIVO DE HASH TABLE
# ------------------------------------------------------------------------------
_load_gcloud_sdk() {
    unset -f gcloud gsutil bq 2>/dev/null
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ ! -d "$GCLOUD_PATH" ] && GCLOUD_PATH="/usr/lib/google-cloud-sdk"
    
    if [ -f "$GCLOUD_PATH/path.zsh.inc" ]; then
        source "$GCLOUD_PATH/path.zsh.inc"
        source "$GCLOUD_PATH/completion.zsh.inc" 2>/dev/null
    fi
}

# Disparadores silenciosos
gcloud() { _load_gcloud_sdk; if [ $# -eq 0 ]; then command gcloud --help; else command gcloud "$@"; fi }
gsutil() { _load_gcloud_sdk; command gsutil "$@" }
bq()     { _load_gcloud_sdk; command bq "$@" }

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
# 6. ALIASES (PRODUCTIVIDAD JORGE OCHOA)
# ------------------------------------------------------------------------------

# Desarrollo (Python, Go, VS Code)
alias python='python3'
alias pip='pip3'
alias g='go'
alias c='code .'
alias v='code'

# Navegación y Listado
if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
else
    alias ll="ls -lAh"
fi

# Gestión de OpenClaw (SRE Partnertech)
alias sc='sudo systemctl'
alias sl='sudo journalctl -u'
alias st='sudo systemctl status'
alias claw-log='sl openclaw -f'
alias gateway-log='sl openclaw-gateway -f'
alias claw-restart='sc restart openclaw openclaw-gateway'

# Git Avanzado (FZF Branch Picker & Rebase Pull)
alias gs="git status -sb"
alias gb="git branch -a | fzf --height 40% --reverse --info=inline | sed 's/.* //;s/remotes\/origin\///' | xargs git checkout"
alias gpl="git pull --rebase"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

# Otros Atajos
alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'

# Sincronización Segura de Dotfiles (Evita el error de Divergent Branches)
dots() {
    local current_dir=$(pwd)
    cd "$DOTFILES"
    echo "🔄 Sincronizando dotfiles..."
    git add .
    git commit -m "SRE: Sync dotfiles $(date)" || echo "No hay cambios para commit."
    git pull --rebase origin main
    git push origin main
    cd "$current_dir"
}

# ------------------------------------------------------------------------------
# 7. HISTORIAL & ENTORNO
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD SHARE_HISTORY INC_APPEND_HISTORY NO_HUP

[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
