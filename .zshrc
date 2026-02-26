# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. PATHS Y ENTORNO UNIVERSAL (SRE 2026)
# ------------------------------------------------------------------------------
typeset -gU path
# Priorizamos binarios de fzf y locales para evitar el error "unknown option --zsh"
path=(
    $HOME/.fzf/bin
    $HOME/.local/bin
    /usr/local/bin
    $path
)
export PATH

# Configuración específica para macOS (Jorge Ochoa)
if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLOUDSDK_PYTHON="python3"
    export NVM_DIR="$HOME/.nvm"
    export ANDROID_HOME=$HOME/Library/Android/sdk
    export GOPATH=$HOME/go
    
    path=(
        $path
        $ANDROID_HOME/platform-tools
        $GOPATH/bin
        $HOME/.opencode/bin
        /opt/homebrew/bin
    )
fi

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS
# ------------------------------------------------------------------------------
# Starship Prompt (Estética y contexto)
command -v starship >/dev/null && eval "$(starship init zsh)"

# Zoxide (Smart CD con memoria)
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# ------------------------------------------------------------------------------
# 4. CARGA DIFERIDA (LAZY LOADING) - OPTIMIZACIÓN
# ------------------------------------------------------------------------------
# Google Cloud SDK (Para servicios de partnertech)
gcloud() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH_MAC="/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
    [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
    [ -f "$GCLOUD_PATH_MAC" ] && . "$GCLOUD_PATH_MAC"
    gcloud "$@"
}

# NVM (Node Version Manager)
nvm() {
    unset -f nvm node npm npx
    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
    nvm "$@"
}
node() { nvm >/dev/null; node "$@" }
npm() { nvm >/dev/null; npm "$@" }

# ------------------------------------------------------------------------------
# 5. ALIASES Y PLUGINS
# ------------------------------------------------------------------------------
# Carga SEGURA de FZF: Evita el error "unknown option --zsh"
if [[ -x "$HOME/.fzf/bin/fzf" ]]; then
    # Si tenemos el binario moderno en .fzf, lo usamos para la carga
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
elif command -v fzf >/dev/null; then
    # Si usamos el del sistema, verificamos si soporta el flag moderno
    if fzf --help | grep -q "\-\-zsh"; then
        eval "$(fzf --zsh)"
    else
        # Carga tradicional para versiones antiguas (v0.24 o menores)
        [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
    fi
fi

# Navegación con Eza (LS moderno)
if command -v eza >/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons'
else
    alias ll='ls -lAh'
fi

# Visualización con Bat
if command -v batcat >/dev/null; then
    alias cat='batcat --paging=never'
    alias bat='batcat'
elif command -v bat >/dev/null; then
    alias cat='bat --paging=never'
fi

# Git y Gestión de Dotfiles
alias gs="git status -sb"
alias dots='cd ~/dotfiles && git add . && git commit -m "Update dots" && git push && cd -'

# Atajo para múltiples sesiones SSH con FZF
alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'

# ------------------------------------------------------------------------------
# 6. SRE FIXES Y ESTABILIDAD
# ------------------------------------------------------------------------------
export TMOUT=0              # Evitar desconexión por inactividad
HISTSIZE=10000
SAVEHIST=10000

setopt AUTO_CD              # cd automático al escribir una ruta
setopt SHARE_HISTORY        # Compartir historial entre terminales
setopt INC_APPEND_HISTORY   # Guardar historial al instante
setopt NO_HUP               # Mantener procesos al cerrar sesión

# Entorno de Edwin / Partnertech
[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
