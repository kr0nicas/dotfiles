# ------------------------------------------------------------------------------
# 0. OPTIMIZACIÓN DE ARRANQUE (INSTANT PROMPT)
# ------------------------------------------------------------------------------
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ------------------------------------------------------------------------------
# 2. DETECCIÓN DE ENTORNO & PATHS (ESTABILIDAD SRE)
# ------------------------------------------------------------------------------
typeset -gU path 

# Priorizamos binarios locales y de fzf para evitar el error "unknown option --zsh"
path=(
    $HOME/.fzf/bin
    $HOME/.local/bin
    /usr/local/bin
    $path
)
export PATH

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
        /opt/homebrew/bin
    )
    export PATH="/Users/jorgeochoa/.opencode/bin:$PATH"
fi

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS (RUST POWERED)
# ------------------------------------------------------------------------------
if command -v starship > /dev/null; then
    eval "$(starship init zsh)"
fi

if command -v zoxide > /dev/null; then
    eval "$(zoxide init zsh)"
fi

if command -v direnv > /dev/null; then
    eval "$(direnv hook zsh)"
fi

# ------------------------------------------------------------------------------
# 4. CARGA DIFERIDA (LAZY LOADING)
# ------------------------------------------------------------------------------
gcloud() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ -f "$GCLOUD_PATH/path.zsh.inc" ] && . "$GCLOUD_PATH/path.zsh.inc"
    [ -f "$GCLOUD_PATH/completion.zsh.inc" ] && . "$GCLOUD_PATH/completion.zsh.inc"
    gcloud "$@"
}
gsutil() { gcloud "$@"; gsutil "$@" }
bq() { gcloud "$@"; bq "$@" }

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

ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

if [ -f "$PLUGIN_DIR_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$PLUGIN_DIR_UBUNTU/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -f "$PLUGIN_DIR_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$PLUGIN_DIR_MAC/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

if [ -f "$PLUGIN_DIR_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$PLUGIN_DIR_UBUNTU/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [ -f "$PLUGIN_DIR_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$PLUGIN_DIR_MAC/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

autoload -Uz compinit && compinit -C
autoload -Uz bashcompinit && bashcompinit

# Carga segura de FZF (evita el error unknown option --zsh si el binario es viejo)
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
elif command -v fzf > /dev/null; then
    # Si no existe el script, intentamos la carga nativa si la versión lo soporta
    fzf_version=$(fzf --version | awk '{print $1}')
    if [[ $(echo "$fzf_version >= 0.48" | bc -l) -eq 1 ]]; then
        eval "$(fzf --zsh)"
    fi
fi

# ------------------------------------------------------------------------------
# 6. ALIASES (PRODUCTIVIDAD SRE)
# ------------------------------------------------------------------------------
if command -v eza > /dev/null; then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons'
    alias lt='eza --tree --level=2 --icons'
else
    alias ll="ls -lAh"
fi

if command -v batcat > /dev/null; then
    alias cat='batcat --paging=never'
    alias bat='batcat'
elif command -v bat > /dev/null; then
    alias cat='bat --paging=never'
fi

alias gs="git status -sb"
alias ga="git add ."
alias gp="git push"
alias gpl="git pull"
alias gl="git log --oneline --graph --all"
alias gcb='git branch -a | fzf | xargs git checkout'
alias py='python3'
alias venv='python3 -m venv venv'
alias va='source venv/bin/activate'
alias dots='cd ~/dotfiles && git add . && git commit -m "Update dots: $(date +%Y-%m-%d)" && git push && cd -'

if command -v nvim > /dev/null; then
    alias vim='nvim'
    alias vi='nvim'
    export EDITOR='nvim'
else
    export EDITOR='vim'
fi

# ------------------------------------------------------------------------------
# 7. CONFIGURACIÓN DE HISTORIAL & ESTABILIDAD
# ------------------------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

export TMOUT=0              
setopt AUTO_CD              
setopt NO_HUP               
setopt INC_APPEND_HISTORY   
setopt SHARE_HISTORY 

[[ -s "$HOME/.autoenv/activate.sh" ]] && source "$HOME/.autoenv/activate.sh"
