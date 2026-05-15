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
        $HOME/google-cloud-sdk/bin
        /usr/local/share/google-cloud-sdk/bin
    )
    export PATH="/Users/jorgeochoa/.opencode/bin:$PATH"
else
    # Linux — Go toolchain en ~/.local/go (sin sudo)
    export GOROOT="$HOME/.local/go"
    export GOPATH="$HOME/go"
    path=(
        $GOROOT/bin
        $GOPATH/bin
        $path
    )
fi

# ------------------------------------------------------------------------------
# 3. INICIALIZACIÓN DE HERRAMIENTAS (RUST POWERED)
# ------------------------------------------------------------------------------
if command -v starship > /dev/null; then
    eval "$(starship init zsh)"
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

# fnm — Node version manager (rápido, lee .nvmrc y .node-version por proyecto)
if command -v fnm > /dev/null; then
    eval "$(fnm env --use-on-cd --shell zsh)"
fi

# ------------------------------------------------------------------------------
# 5. PLUGINS & COMPLETIONS
# ------------------------------------------------------------------------------
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20

# Busca plugins en todas las rutas posibles (Ubuntu, Mac Intel, Mac Apple Silicon)
_source_plugin() {
    local plugin=$1
    for dir in /usr/share /usr/local/share /opt/homebrew/share; do
        if [ -f "$dir/$plugin/$plugin.zsh" ]; then
            source "$dir/$plugin/$plugin.zsh"
            return
        fi
    done
}

_source_plugin zsh-autosuggestions
_source_plugin zsh-syntax-highlighting

autoload -Uz compinit && compinit -C
autoload -Uz bashcompinit && bashcompinit

# Carga segura de FZF (evita el error unknown option --zsh si el binario es viejo)
if [[ -f ~/.fzf.zsh ]]; then
    source ~/.fzf.zsh
elif command -v fzf > /dev/null; then
    # Si no existe el script, intentamos la carga nativa si la versión lo soporta
    fzf_version=$(fzf --version | awk '{print $1}')
    fzf_major=$(echo "$fzf_version" | cut -d. -f1)
    fzf_minor=$(echo "$fzf_version" | cut -d. -f2)
    if [[ $fzf_major -gt 0 ]] || [[ $fzf_major -eq 0 && $fzf_minor -ge 48 ]]; then
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

# SSH: lista hosts y conecta con fzf
ssh-pick() {
    local host
    host=$(grep '^Host ' ~/.ssh/config | grep -v '[*?]' | awk '{print $2}' \
        | fzf --prompt="ssh > " --height=40%)
    [[ -n "$host" ]] && ssh "$host"
}
alias sp='ssh-pick'

# Kubernetes
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deploy'
alias kga='kubectl get all'
alias kl='kubectl logs -f'
alias ke='kubectl exec -it'
alias kns='kubens'
alias kctx='kubectx'

# Terraform
alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfs='terraform state list'

# Docker Compose
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'

# Clipboard cross-platform
if [[ "$OSTYPE" == "darwin"* ]]; then
    alias xclip='pbcopy'
else
    pbcopy() {
        if [[ -n "$DISPLAY" ]]; then
            xclip -selection clipboard
        else
            # OSC 52: funciona sobre SSH en terminales modernas (iTerm2, WezTerm, kitty, etc.)
            printf "\033]52;c;%s\a" "$(base64 | tr -d '\n')"
        fi
    }
fi

# WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    alias expose-ports='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass -File C:\\Scripts\\wsl-portproxy.ps1'
fi

# GCP: cambiar entre configuraciones/cuentas
alias gcpers='gcloud config configurations activate personal && echo "→ personal (ochoa.j@gmail.com)"'
alias gcit='gcloud config configurations activate itproject && echo "→ ITProject (jorge.ochoa@itproject41.com)"'
alias gcfact='gcloud config configurations activate facturaya && echo "→ Facturaya (administrator@facturayasv.com)"'
alias gcwho='gcloud config list --format="value(core.account,core.project)" 2>/dev/null | paste - - | column -t'

# Tools
alias lg='lazygit'
alias cheat='bat ~/dotfiles/CHEAT_CODES.md'
alias top='btop'
alias du='dust'

# Tmux sessionizer: abre/crea sesion por proyecto con fzf
t() {
    local dir name
    dir=$(find ~/projects ~/go/src -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
        | fzf --prompt="tmux > " --height=40%)
    [[ -z "$dir" ]] && return
    name=$(basename "$dir" | tr '.' '_')
    if tmux has-session -t="$name" 2>/dev/null; then
        tmux attach -t "$name"
    else
        tmux new-session -d -s "$name" -c "$dir"
        tmux attach -t "$name"
    fi
}

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

# zoxide (debe ir al final)
if command -v zoxide > /dev/null; then
    eval "$(zoxide init zsh)"
fi

# Configuración local del host (no se sincroniza con dotfiles)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# opencode (carga condicional para evitar errores en macOS)
[[ -d "$HOME/.opencode/bin" ]] && export PATH="$HOME/.opencode/bin:$PATH"

# OpenClaw Completion (carga condicional)
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && source "$HOME/.openclaw/completions/openclaw.zsh"

[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
