# ==============================================================================
# .ZSHRC — Jorge Ochoa | SRE Config | macOS + Debian + Ubuntu
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. DETECCIÓN DE SISTEMA Y DIAGNÓSTICO
# ------------------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    export IS_MAC=1
    export OS_NAME="macOS"
else
    export IS_MAC=0
    export OS_NAME=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "Linux")
fi

alias sre-debug='echo "✅ Entorno: $OS_NAME | User: $USER | PATH: $PATH"'

# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. FIX DE AUTOCOMPLETADO (NESTING LEVEL ERROR)
# ------------------------------------------------------------------------------
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.zcompcache"

autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.m-1) ]]; then
  compinit -C
else
  compinit -i
fi

# ------------------------------------------------------------------------------
# 3. CONFIGURACIÓN MAESTRA DE PATHS
# ------------------------------------------------------------------------------
typeset -gU path
export DOTFILES="$HOME/dotfiles"

path=(
    $HOME/.local/bin
    $HOME/bin
    $HOME/.cargo/bin        # Importante para 'uv' y difftastic
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
# 4. INICIALIZACIÓN DE HERRAMIENTAS
# ------------------------------------------------------------------------------
command -v starship > /dev/null && eval "$(starship init zsh)"
command -v zoxide  > /dev/null && eval "$(zoxide init zsh)"

# ------------------------------------------------------------------------------
# 5. CARGA DIFERIDA (LAZY LOADING)
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

gcloud() { _load_gcloud_sdk; command gcloud "$@" }
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

# FIX: stderr en lugar de stdout para no suprimir errores reales
node() { nvm 2>/dev/null; command node "$@" }
npm()  { nvm 2>/dev/null; command npm  "$@" }
npx()  { nvm 2>/dev/null; command npx  "$@" }

# ------------------------------------------------------------------------------
# 6. PLUGINS & COMPLETIONS (FZF, UV, GH)
# ------------------------------------------------------------------------------
if [[ $IS_MAC -eq 1 ]]; then
    P_DIR="/opt/homebrew/share"
else
    P_DIR="/usr/share"
fi

[[ -f "$P_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$P_DIR/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -f "$P_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]         && source "$P_DIR/zsh-autosuggestions/zsh-autosuggestions.zsh"

# FZF
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
elif command -v fzf > /dev/null; then
    if fzf --help 2>/dev/null | grep -q "\-\-zsh"; then
        eval "$(fzf --zsh 2>/dev/null)"
    fi
fi

# UV & GH Completions
command -v uv > /dev/null && eval "$(uv generate-shell-completion zsh)"
command -v gh > /dev/null && eval "$(gh completion -s zsh)"

# ------------------------------------------------------------------------------
# 7. ALIASES (PRODUCTIVIDAD)
# ------------------------------------------------------------------------------
unalias dots 2>/dev/null

alias python='python3'
alias pip='uv pip'
alias g='go'
alias c='code .'
alias v='vim'

if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
else
    alias ll="ls -lAh"
fi

# OpenClaw SRE (solo Linux)
if [[ $IS_MAC -eq 0 ]]; then
    alias sc='sudo systemctl'
    alias sl='sudo journalctl -u'
    alias st='sudo systemctl status'
    alias claw-log='sl openclaw -f'
    alias gateway-log='sl openclaw-gateway -f'
    alias claw-restart='sc restart openclaw openclaw-gateway'
fi

alias myip='curl -s https://ifconfig.me && echo'

# Git
alias gs="git status -sb"
alias gb="git branch -a | fzf --height 40% --reverse --info=inline | sed 's/.* //;s/remotes\/origin\///' | xargs git checkout"
alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

alias ezsh='vim ~/.zshrc && source ~/.zshrc'
alias v-help='bat ~/dotfiles/vim_guide.md'

# ------------------------------------------------------------------------------
# 8. FUNCIONES SRE
# ------------------------------------------------------------------------------

# Sincronizar dotfiles con manejo de errores
dots() {
    local c_dir=$(pwd)
    cd "$DOTFILES" || return 1
    echo "🔄 Sincronizando dotfiles en $OS_NAME..."
    git add .
    git commit -m "SRE: Sync dotfiles ($OS_NAME) $(date)" || echo "ℹ️  Sin cambios nuevos."
    git pull --rebase origin main || { echo "❌ Pull falló. Abortando."; cd "$c_dir"; return 1; }
    git push origin main && echo "✅ Dotfiles sincronizados." || echo "❌ Push falló."
    cd "$c_dir"
}

# Health check del entorno — útil al conectarse a un servidor nuevo
sre-check() {
    echo "=== SRE Environment Check ================"
    echo "OS:      $OS_NAME"
    echo "User:    $USER"
    echo "Shell:   $ZSH_VERSION"
    echo "Host:    $(hostname)"
    echo "------------------------------------------"
    echo "Tools:"
    for t in git vim curl jq fzf uv gh gcloud docker kubectl helm bat delta btop; do
        printf "  %-12s %s\n" "$t" "$(command -v $t 2>/dev/null || echo '❌ not found')"
    done
    echo "=========================================="
}

# Puertos en escucha — función en lugar de alias para evaluar IS_MAC correctamente
unalias ports 2>/dev/null
ports() {
    if [[ $IS_MAC -eq 1 ]]; then
        sudo lsof -i -P -n | grep LISTEN
    else
        sudo ss -tulpn | grep LISTEN
    fi
}

# Matar proceso por puerto
port-kill() {
    [[ -z "$1" ]] && echo "Uso: port-kill <puerto>" && return 1
    local pid=$(lsof -ti tcp:"$1")
    [[ -z "$pid" ]] && echo "⚠️  Sin proceso en puerto $1" && return
    kill -9 $pid && echo "✅ PID $pid eliminado (puerto $1)"
}

# Crear directorio y entrar
mkcd() { mkdir -p "$1" && cd "$1" }

# Backup rápido de archivo antes de editar en producción
bak() {
    [[ -z "$1" ]] && echo "Uso: bak <archivo>" && return 1
    local dest="$1.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$1" "$dest" && echo "📦 Backup creado: $dest"
}

# HTTP server local inmediato
serve() { python3 -m http.server "${1:-8080}" }

# Limpiar ramas Git locales ya mergeadas
git-clean() {
    git branch --merged | grep -vE '^\*|main|master|develop' | xargs -r git branch -d
    echo "✅ Ramas locales mergeadas eliminadas."
}

# Extraer cualquier archivo comprimido con un solo comando
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)  tar xjf "$1"    ;;
            *.tar.gz)   tar xzf "$1"    ;;
            *.tar.xz)   tar xJf "$1"    ;;
            *.bz2)      bunzip2 "$1"    ;;
            *.gz)       gunzip "$1"     ;;
            *.tar)      tar xf "$1"     ;;
            *.zip)      unzip "$1"      ;;
            *.7z)       7z x "$1"       ;;
            *)          echo "❌ No sé cómo extraer '$1'" ;;
        esac
    else
        echo "❌ '$1' no es un archivo válido"
    fi
}

# ------------------------------------------------------------------------------
# 9. SSH — Carga automática de llaves (solo Mac)
# ------------------------------------------------------------------------------
if [[ $IS_MAC -eq 1 ]]; then
    ssh-add --apple-load-keychain 2>/dev/null
fi

# ------------------------------------------------------------------------------
# 10. HISTORIAL & OPCIONES FINALES
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD SHARE_HISTORY INC_APPEND_HISTORY NO_HUP

# ------------------------------------------------------------------------------
# 11. CARGA FINAL DE COMPLETIONS OPCIONALES
# ------------------------------------------------------------------------------
[[ -s "$HOME/.autoenv/activate.sh" ]]                          && source "$HOME/.autoenv/activate.sh"
[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]              && source "$HOME/.openclaw/completions/openclaw.zsh" 2>/dev/null
[ -s "$NVM_DIR/bash_completion" ]                              && \. "$NVM_DIR/bash_completion"
