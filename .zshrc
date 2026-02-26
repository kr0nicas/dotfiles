# ------------------------------------------------------------------------------
# 1. COLORES Y ESTÉTICA (FIX PRIORITARIO PARA MAC OS)
# ------------------------------------------------------------------------------
export TERM="xterm-256color"
export COLORTERM="truecolor"
export CLICOLOR=1

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE ICONO PARA EL PROMPT (SRE 2026)
# ------------------------------------------------------------------------------
if [[ "$OSTYPE" == "darwin"* ]]; then
    export OS_ICON="🍎"
    export OS_NAME="Mac OS"
elif [[ -f /etc/os-release ]]; then
    os_id=$(grep -i '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    case "$os_id" in
        ubuntu) export OS_ICON=""; export OS_NAME="Ubuntu" ;;
        debian) export OS_ICON=""; export OS_NAME="Debian" ;;
        *) export OS_ICON="🐧"; export OS_NAME="Linux" ;;
    esac
else
    export OS_ICON="💻"; export OS_NAME="Terminal"
fi

# ------------------------------------------------------------------------------
# 3. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 4. PATHS Y ENTORNO UNIVERSAL
# ------------------------------------------------------------------------------
typeset -gU path
path=($HOME/.fzf/bin $HOME/.local/bin /usr/local/bin $path)
export PATH

if [[ "$OSTYPE" == "darwin"* ]]; then
    export CLOUDSDK_PYTHON="python3"
    export NVM_DIR="$HOME/.nvm"
    export ANDROID_HOME=$HOME/Library/Android/sdk
    export GOPATH=$HOME/go
    path=($path $ANDROID_HOME/platform-tools $GOPATH/bin $HOME/.opencode/bin /opt/homebrew/bin)
fi

# ------------------------------------------------------------------------------
# 5. TMUX & SSH WORKFLOW (MEJORA SRE)
# ------------------------------------------------------------------------------
# Alias para TMUX
alias tl='tmux ls'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'

# Función SSH + TMUX: Se conecta y abre/recupera sesión 'main' automáticamente
ssht() {
    ssh -t "$1" "tmux attach || tmux new"
}

# ------------------------------------------------------------------------------
# 6. INICIALIZACIÓN DE HERRAMIENTAS
# ------------------------------------------------------------------------------
export STARSHIP_CONFIG="$HOME/dotfiles/config/starship/starship.toml"
command -v starship >/dev/null && eval "$(starship init zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# ------------------------------------------------------------------------------
# 7. CARGA DIFERIDA (LAZY LOADING)
# ------------------------------------------------------------------------------
gcloud() {
    unset -f gcloud gsutil bq
    [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
    gcloud "$@"
}
nvm() {
    unset -f nvm node npm npx
    [ -s "$HOME/.nvm/nvm.sh" ] && . "$HOME/.nvm/nvm.sh"
    nvm "$@"
}

# ------------------------------------------------------------------------------
# 8. ALIASES Y PLUGINS
# ------------------------------------------------------------------------------
PLUGIN_MAC="/opt/homebrew/share"
PLUGIN_UBUNTU="/usr/share"

# Plugins
[[ -f "$PLUGIN_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]] && source "$PLUGIN_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -f "$PLUGIN_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh" ]] && source "$PLUGIN_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh"
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# Aliases
alias ls='eza --icons --group-directories-first'
alias ll='eza -lh --icons --git'
alias gs="git status -sb"
alias dots='cd ~/dotfiles && git add . && git commit -m "Update dots: $(date)" && git push && cd -'
alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'

# ------------------------------------------------------------------------------
# 9. SRE FIXES & PARTNERTECH
# ------------------------------------------------------------------------------
export TMOUT=0
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD SHARE_HISTORY INC_APPEND_HISTORY NO_HUP

[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"

clear
echo -e "${OS_ICON}  Bienvenido a tu entorno ${OS_NAME}, Jorge."
