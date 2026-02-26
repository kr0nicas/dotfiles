# ------------------------------------------------------------------------------
# 1. COLORES Y ESTÉTICA (FIX PRIORITARIO PARA MAC OS)
# ------------------------------------------------------------------------------
# Forzamos el soporte de 256 colores y True Color antes de cualquier otra cosa
export TERM="xterm-256color"
export COLORTERM="truecolor"
export CLICOLOR=1

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE ICONO SEGÚN SISTEMA (NUEVO)
# ------------------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    export OS_ICON="🍎"
    export OS_NAME="Mac OS"
elif [[ -f /etc/os-release ]]; then
    # Extraemos el ID de la distribución en Linux
    os_id=$(grep -i '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    case "$os_id" in
        ubuntu)
            export OS_ICON="" # Icono de Ubuntu (requiere Nerd Font)
            export OS_NAME="Ubuntu"
            ;;
        debian)
            export OS_ICON="" # Icono de Debian (requiere Nerd Font)
            export OS_NAME="Debian"
            ;;
        *)
            export OS_ICON="🐧"
            export OS_NAME="Linux"
            ;;
    esac
else
    export OS_ICON="💻"
    export OS_NAME="Terminal"
fi

# ------------------------------------------------------------------------------
# 3. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 4. PATHS Y ENTORNO UNIVERSAL (SRE 2026)
# ------------------------------------------------------------------------------
typeset -gU path
path=(
    $HOME/.fzf/bin
    $HOME/.local/bin
    /usr/local/bin
    $path
)
export PATH

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
# 5. INICIALIZACIÓN DE HERRAMIENTAS (STARSHIP FIX)
# ------------------------------------------------------------------------------
# Forzamos la ruta de configuración para que Starship no use la de por defecto
export STARSHIP_CONFIG="$HOME/.config/starship.toml"

if command -v starship >/dev/null; then
    eval "$(starship init zsh)"
fi

# Zoxide
if command -v zoxide >/dev/null; then
    eval "$(zoxide init zsh)"
fi

# ------------------------------------------------------------------------------
# 6. CARGA DIFERIDA (LAZY LOADING) - OPTIMIZACIÓN
# ------------------------------------------------------------------------------
gcloud() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH_MAC="/usr/local/Caskroom/google-cloud-sdk/latest/google-cloud-sdk/path.zsh.inc"
    [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
    [ -f "$GCLOUD_PATH_MAC" ] && . "$GCLOUD_PATH_MAC"
    gcloud "$@"
}

nvm() {
    unset -f nvm node npm npx
    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
    nvm "$@"
}
node() { nvm >/dev/null; node "$@" }
npm() { nvm >/dev/null; npm "$@" }

# ------------------------------------------------------------------------------
# 7. ALIASES Y PLUGINS (RESCATE DE COLORES)
# ------------------------------------------------------------------------------
PLUGIN_UBUNTU="/usr/share"
PLUGIN_MAC="/opt/homebrew/share"

# Syntax Highlighting
if [ -f "$PLUGIN_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$PLUGIN_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [ -f "$PLUGIN_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$PLUGIN_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# Autosuggestions
if [ -f "$PLUGIN_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$PLUGIN_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -f "$PLUGIN_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$PLUGIN_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# Carga SEGURA de FZF
if [[ -x "$HOME/.fzf/bin/fzf" ]]; then
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
elif command -v fzf >/dev/null; then
    if fzf --help | grep -q "\-\-zsh"; then
        eval "$(fzf --zsh)"
    else
        [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
    fi
fi

# Navegación con Eza
if command -v eza >/dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons'
else
    alias ll='ls -lAh --color=auto'
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
# 8. SRE FIXES Y ESTABILIDAD
# ------------------------------------------------------------------------------
export TMOUT=0
HISTSIZE=10000
SAVEHIST=10000

setopt AUTO_CD
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
setopt NO_HUP

# Entorno de Edwin / Partnertech
[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"

# Mensaje de bienvenida con el icono detectado
echo -e "Estás en: ${OS_ICON}  ${OS_NAME}"
