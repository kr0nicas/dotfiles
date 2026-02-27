# ------------------------------------------------------------------------------
# 0. DETECCIÓN DE SISTEMA Y DIAGNÓSTICO
# ------------------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    export IS_MAC=1
    export OS_NAME="macOS"
else
    export IS_MAC=0
    export OS_NAME="Linux/Ubuntu"
fi

alias sre-debug='echo "✅ Entorno: $OS_NAME | User: $USER | PATH: $PATH"'

# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. CONFIGURACIÓN MAESTRA DE PATHS
# ------------------------------------------------------------------------------
typeset -gU path 

path=(
    $HOME/.local/bin
    $HOME/bin
    $HOME/.krew/bin
    $HOME/go/bin
    /usr/local/bin
    /usr/local/sbin
    /usr/bin
    /usr/sbin
    /bin
    /sbin
    $path
)

if [[ $IS_MAC -eq 1 ]]; then
    export CLOUDSDK_PYTHON="python3"
    export NVM_DIR="$HOME/.nvm"
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    path=($path /opt/homebrew/bin $ANDROID_HOME/platform-tools)
    [[ -f "/opt/homebrew/bin/brew" ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
else
    [[ -d "/snap/bin" ]] && path=($path /snap/bin)
fi

[[ -d "$HOME/google-cloud-sdk" ]] && path=($HOME/google-cloud-sdk/bin $path)

export PATH
export GOPATH="$HOME/go"
export EDITOR='vim'
export VISUAL='vim'

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS
# ------------------------------------------------------------------------------
command -v starship > /dev/null && eval "$(starship init zsh)"
command -v zoxide > /dev/null && eval "$(zoxide init zsh)"

# ------------------------------------------------------------------------------
# 4. CARGA DIFERIDA (LAZY LOADING)
# ------------------------------------------------------------------------------
_load_gcloud_sdk() {
    unset -f gcloud gsutil bq 2>/dev/null
    local G_PATH="$HOME/google-cloud-sdk"
    [[ ! -d "$G_PATH" ]] && G_PATH="/usr/lib/google-cloud-sdk"
    
    if [[ -f "$G_PATH/path.zsh.inc" ]]; then
        source "$G_PATH/path.zsh.inc"
        source "$G_PATH/completion.zsh.inc" 2>/dev/null
    fi
}

gcloud() { _load_gcloud_sdk; [[ $# -eq 0 ]] && command gcloud --help || command gcloud "$@" }
gsutil() { _load_gcloud_sdk; command gsutil "$@" }
bq()     { _load_gcloud_sdk; command bq "$@" }

nvm() {
    unset -f nvm node npm npx 2>/dev/null
    export NVM_DIR="$HOME/.nvm"
    local NVM_SCRIPT
    [[ $IS_MAC -eq 1 ]] && NVM_SCRIPT="/usr/local/opt/nvm/nvm.sh" || NVM_SCRIPT="$NVM_DIR/nvm.sh"
    [[ -s "$NVM_SCRIPT" ]] && . "$NVM_SCRIPT"
    nvm "$@"
}

# ------------------------------------------------------------------------------
# 5. PLUGINS & COMPLETIONS (COMPATIBILIDAD FZF)
# ------------------------------------------------------------------------------
if [[ $IS_MAC -eq 1 ]]; then
    P_DIR="/opt/homebrew/share"
else
    P_DIR="/usr/share"
fi

[[ -f "$P_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$P_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -f "$P_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$P_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"

# Carga de fzf (Manejo ultra-seguro para versiones antiguas)
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
elif command -v fzf > /dev/null; then
    # Solo intentamos ejecutar --zsh si el comando no devuelve error al preguntar por esa opción
    if fzf --help 2>&1 | grep -q "\-\-zsh"; then
        eval "$(fzf --zsh 2>/dev/null)"
    fi
fi

# ------------------------------------------------------------------------------
# 6. ALIASES (PRODUCTIVIDAD JORGE OCHOA)
# ------------------------------------------------------------------------------

# Limpieza preventiva de alias que puedan chocar con funciones posteriores
unalias dots 2>/dev/null

# Desarrollo y Editores
alias python='python3'
alias pip='pip3'
alias g='go'
alias c='code .'
alias v='code'

if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
else
    alias ll="ls -lAh"
fi

# Gestión de OpenClaw y SRE (Ubuntu Server)
if [[ $IS_MAC -eq 0 ]]; then
    alias sc='sudo systemctl'
    alias sl='sudo journalctl -u'
    alias st='sudo systemctl status'
    alias claw-log='sl openclaw -f'
    alias gateway-log='sl openclaw-gateway -f'
    alias claw-restart='sc restart openclaw openclaw-gateway'
fi

alias myip='curl -s https://ifconfig.me && echo'
alias ports='[[ $IS_MAC -eq 1 ]] && sudo lsof -i -P -n | grep LISTEN || sudo ss -tulpn | grep LISTEN'

# Diagnóstico de herramientas
alias fzf-check='fzf --help 2>&1 | grep -q "\-\-zsh" && echo "✅ fzf soporta --zsh" || echo "⚠️ fzf es versión antigua (No soporta --zsh)"'

# Seguridad
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Git Avanzado
alias gs="git status -sb"
alias gb="git branch -a | fzf --height 40% --reverse --info=inline | sed 's/.* //;s/remotes\/origin\///' | xargs git checkout"
alias gpl="git pull --rebase"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'
alias ezsh='vim ~/.zshrc && source ~/.zshrc'

# ------------------------------------------------------------------------------
# 7. FUNCIONES SRE (NORMALIZADAS)
# ------------------------------------------------------------------------------

# Sincronización Segura de Dotfiles
dots() {
    local c_dir=$(pwd)
    cd "$DOTFILES"
    echo "🔄 Sincronizando dotfiles en $OS_NAME..."
    git add .
    git commit -m "SRE: Sync dotfiles ($OS_NAME) $(date)" || echo "Sin cambios pendientes."
    git pull --rebase origin main
    git push origin main
    cd "$c_dir"
}

# ------------------------------------------------------------------------------
# 8. HISTORIAL & ENTORNO
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD SHARE_HISTORY INC_APPEND_HISTORY NO_HUP

[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
