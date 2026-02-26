# ------------------------------------------------------------------------------
# 0. DIAGNÓSTICO DE CARGA (SRE-DEBUG)
# ------------------------------------------------------------------------------
alias sre-debug='echo "✅ Entorno Cargado | OS: $OSTYPE | DOTFILES: $DOTFILES | User: $USER"'

# ------------------------------------------------------------------------------
# 1. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE ENTORNO & PATHS
# ------------------------------------------------------------------------------
typeset -gU path # Evita duplicados en el PATH
export DOTFILES="$HOME/dotfiles"

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
    export ANDROID_HOME="$HOME/Library/Android/sdk"
    export GOPATH="$HOME/go"
    
    path=(
        $path
        $HOME/.krew/bin
        /opt/homebrew/bin
        /usr/local/bin
        $ANDROID_HOME/platform-tools
        $GOPATH/bin
        $HOME/.opencode/bin
    )
    
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
# 4. CARGA DIFERIDA (LAZY LOADING)
# ------------------------------------------------------------------------------
gcloud() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ -f "$GCLOUD_PATH/path.zsh.inc" ] && . "$GCLOUD_PATH/path.zsh.inc"
    gcloud "$@"
}

nvm() {
    unset -f nvm node npm npx
    [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm "$@"
}

# ------------------------------------------------------------------------------
# 5. PLUGINS & COMPLETIONS (CARGA SEGURA DE FZF)
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

if [[ -x "$HOME/.fzf/bin/fzf" ]]; then
    [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
elif command -v fzf > /dev/null; then
    if fzf --help | grep -q "\-\-zsh"; then
        eval "$(fzf --zsh)"
    else
        [[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
    fi
fi

# ------------------------------------------------------------------------------
# 6. ALIASES (PRODUCTIVIDAD SRE)
# ------------------------------------------------------------------------------
if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
else
    alias ll="ls -lAh"
fi

# Homebrew Aliases
if command -v brew > /dev/null; then
    alias blist='cat "$DOTFILES/Brewfile"'
    alias bcheck='brew bundle list --file="$DOTFILES/Brewfile"'
    alias bclean='brew bundle cleanup --file="$DOTFILES/Brewfile"'
    alias bdump='brew bundle dump --force --file="$DOTFILES/Brewfile"'
fi

# SSH & TMUX
alias s='grep -iE "^host " ~/.ssh/config | awk "{print \$2}" | fzf --reverse | xargs -o ssh'
ssht() { ssh -t "$1" "tmux attach || tmux new"; }

# Gestión de Servicios (SRE Essentials)
alias sc='sudo systemctl'
alias sl='sudo journalctl -u' 
alias st='sudo systemctl status'

# Alias específicos para OpenClaw (Partnertech)
alias claw-log='sl openclaw -f'
alias gateway-log='sl openclaw-gateway -f'
alias claw-restart='sc restart openclaw openclaw-gateway'

# Auditoría de Root
# Lista procesos corriendo como root ignorando hilos del kernel
alias check-root='ps -U root -u root u | grep -v "\["'

# Privilegios Elevados
alias root='sudo -i'
alias god='sudo -s'

alias gs="git status -sb"
alias dots='cd "$DOTFILES" && git add . && git commit -m "Update dots: $(date)" && git push && cd -'

# ------------------------------------------------------------------------------
# 7. HISTORIAL & ESTABILIDAD
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt AUTO_CD NO_HUP INC_APPEND_HISTORY SHARE_HISTORY 

[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
