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
# gcloud/gsutil/bq: el SDK tarda en cargar, así que diferimos path y completions
# hasta la primera invocación. El helper NO recibe los argumentos del comando:
# pasárselos hacía que `gsutil ls ...` ejecutase antes `gcloud ls ...` y
# escupiera un error en cada primer uso.
_gcloud_lazy_load() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ -f "$GCLOUD_PATH/path.zsh.inc" ] && . "$GCLOUD_PATH/path.zsh.inc"
    [ -f "$GCLOUD_PATH/completion.zsh.inc" ] && . "$GCLOUD_PATH/completion.zsh.inc"
    return 0   # el último [ -f ] puede ser falso; no propagar ese estado
}
gcloud() { _gcloud_lazy_load; gcloud "$@" }
gsutil() { _gcloud_lazy_load; gsutil "$@" }
bq()     { _gcloud_lazy_load; bq "$@" }

# GCP: switcher de cuentas y proyectos (comando `gcx`, ver `gcx -h`)
[ -f "$HOME/dotfiles/config/zsh/gcp.zsh" ] && source "$HOME/dotfiles/config/zsh/gcp.zsh"

# fnm — Node version manager (rápido, lee .nvmrc y .node-version por proyecto)
if command -v fnm > /dev/null; then
    eval "$(fnm env --use-on-cd --shell zsh)"
    # fnm antepone su shim al PATH. Re-anteponemos ~/.local/bin para que binarios
    # standalone (claude, etc.) ganen sobre cualquier global de npm en un node version.
    path=( $HOME/.local/bin $path )
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
# dots — guardar cambios de los dotfiles bajo el flujo de rama + PR.
# Antes era un alias que hacía `git add . && commit "Update dots: $(date)" && push`
# sobre main: bajo las reglas del repo falla en tres sitios a la vez (rama
# prohibida, mensaje inválido y add indiscriminado).
dots() {
    local msg="$1" rama
    if [[ -z "$msg" ]]; then
        print -u2 "  ✗ uso: dots '<tipo>(<ámbito>): <asunto>'"
        print -u2 "     ej: dots 'fix(zshrc): quitar alias que rompía du'"
        return 2
    fi

    ( cd "$HOME/dotfiles" || return 1

      if [[ "$(git branch --show-current)" == "main" ]]; then
          # feat(iterm2): perfil dinámico  ->  feat/iterm2-perfil-dinamico
          #
          # El `tr -d` de abajo NO es redundante con el `sed` final: el iconv
          # de BSD (macOS) no transcribe "á" a "a", antepone la marca
          # diacrítica suelta ("á"->"'a", "ñ"->"~n", "ü"/"ö"->"\"u"/"\"o",
          # "â"/"ê"->"^a"/"^e"). Sin borrarlas aquí, el sed final las trata
          # como carácter no válido y las convierte en guion, partiendo la
          # palabra ("dinámico" -> "din-amico" en vez de "dinamico"). En
          # Linux (glibc) iconv ya transcribe limpio y el `tr` no hace nada.
          rama=$(print -r -- "$msg" \
              | sed -E 's/^([a-z]+)\(([a-z0-9.-]+)\): /\1\/\2-/; s/^([a-z]+): /\1\//' \
              | tr '[:upper:]' '[:lower:]' \
              | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
              | tr -d "'~^\"\`" \
              | sed -E 's/[^a-z0-9\/-]+/-/g; s/-+/-/g; s/-$//' \
              | cut -c1-60)
          git switch -c "$rama" || return 1
      fi

      git add -A
      if ! git commit -m "$msg"; then
          print -u2 "  ✗ el commit falló; los cambios siguen en stage."
          print -u2 "     rama: $(git branch --show-current)"
          print -u2 "     arregla el mensaje (mira el error del hook arriba) y corre:"
          print -u2 "       git commit -m '$msg'"
          return 1
      fi

      # El CHANGELOG queda obsoleto en cuanto entra el commit de código, y
      # changelog-drift es un check requerido. Va en su propio commit: si se
      # mezcla con el de código, el archivo no converge.
      if [[ -x scripts/changelog.sh ]]; then
          ./scripts/changelog.sh > /dev/null
          if [[ -n "$(git status --porcelain CHANGELOG.md)" ]]; then
              git add CHANGELOG.md && git commit -m 'chore(repo): regenerar CHANGELOG'
          fi
      fi

      git push -u origin HEAD || return 1

      if command -v gh > /dev/null && [[ -z "$(gh pr view --json number 2>/dev/null)" ]]; then
          gh pr create --fill
      fi
    )
}

# SSH: lista hosts y conecta con fzf
ssh-pick() {
    local host
    host=$(grep '^Host ' ~/.ssh/config | grep -v '[*?]' | awk '{print $2}' \
        | fzf --prompt="ssh > " --height=40%)
    [[ -n "$host" ]] && ssh "$host"
}
alias sp='ssh-pick'

# Resuelve el destino de una línea de ssh: el PRIMER argumento que no es un
# flag ni el valor de uno, sin el "usuario@" delante.
#
# Antes esto era un bucle que se quedaba con el ÚLTIMO argumento no-flag, y eso
# devuelve el comando en vez del host en cuanto pasas uno:
#   ssh prod-web ls -la              -> "ls"
#   ssh prod-web systemctl restart   -> "restart"
# Degradaba en silencio (solo se perdía el color), pero se perdía justo al
# ejecutar un comando suelto contra producción, que es cuando más quieres ver
# el fondo rojo.
#
# La clase de caracteres son las opciones de ssh que llevan valor separado; sin
# saltarse ese valor, `ssh -p 2222 host` tomaría "2222" como destino.
_ssh_target() {
    local skip_next=0 arg
    for arg in "$@"; do
        if (( skip_next )); then skip_next=0; continue; fi
        case "$arg" in
            -[BbcDEeFIiJLlmOopQRSWw]) skip_next=1 ;;
            -*) ;;
            *)  print -- "${arg#*@}"; return 0 ;;
        esac
    done
    return 1
}

# SSH Color wrapper — cambia el fondo del terminal según el servidor
# Compatible con iTerm2 (OSC 1337) y terminales estándar (OSC 11)
ssh() {
    local host
    host=$(_ssh_target "$@") || host=""

    # Leer mapa de colores desde dotfiles (o ~/.ssh/colors.conf como override local)
    local color_conf=""
    for f in "$HOME/.ssh/colors.conf" "$HOME/dotfiles/config/ssh/colors.conf"; do
        [[ -f "$f" ]] && color_conf="$f" && break
    done

    local bg="" label="" emoji=""
    if [[ -n "$color_conf" && -n "$host" ]]; then
        while IFS='|' read -r pattern bg_val lbl emj || [[ -n "$pattern" ]]; do
            [[ "$pattern" =~ ^#.*$ || -z "$pattern" ]] && continue
            if [[ "${host:l}" == *"${pattern:l}"* ]]; then
                bg="$bg_val" label="$lbl" emoji="$emj"
                break
            fi
        done < "$color_conf"
    fi

    # Función interna: cambiar background (iTerm2 + xterm estándar)
    _ssh_set_bg() {
        local hex="$1"
        if [[ -n "$TMUX" ]]; then
            # En tmux hay que envolver el escape con DCS passthrough
            printf '\033Ptmux;\033\033]1337;SetColors=bg=%s\007\033\\' "$hex"
            printf '\033Ptmux;\033\033]11;#%s\007\033\\' "$hex"
        else
            printf '\033]1337;SetColors=bg=%s\007' "$hex"   # iTerm2
            printf '\033]11;#%s\007' "$hex"                 # xterm estándar
        fi
    }

    # Restaurar fondo original al salir (Catppuccin Mocha base: #1e1e2e)
    _ssh_reset_bg() {
        if [[ -n "$TMUX" ]]; then
            printf '\033Ptmux;\033\033]1337;SetColors=bg=1e1e2e\007\033\\'
            printf '\033Ptmux;\033\033]11;#1e1e2e\007\033\\'
        else
            printf '\033]1337;SetColors=bg=1e1e2e\007'
            printf '\033]11;#1e1e2e\007'
        fi
    }

    # Aplicar color y mostrar banner si hay coincidencia
    if [[ -n "$bg" ]]; then
        _ssh_set_bg "$bg"
        echo ""
        echo "  ${emoji} ${label} → ${host}"
        echo "  ─────────────────────────────"
    fi

    # Conectar
    command ssh "$@"
    local exit_code=$?

    # Restaurar siempre al salir
    [[ -n "$bg" ]] && _ssh_reset_bg

    return $exit_code
}

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

# GCP: cambiar entre configuraciones/cuentas (ver `gcx -h`)
# Delegan en `gcx use`, que valida e imprime el estado leído de gcloud.
# Nunca vuelvas a poner la cuenta en un echo: es lo que hizo que mintieran.
alias gcpers='gcx use personal'
alias gcit='gcx use itproject'
alias gcfact='gcx use facturaya'
alias gckel='gcx use kelova'
alias gcwho='gcx who'

# Tools
alias lg='lazygit'
alias cheat='bat ~/dotfiles/CHEAT_CODES.md'
# Sin alias de `du` ni `top`: `dust` y `btop` ya están en el PATH con su nombre.
# Aliasarlos rompía los originales — en dust, `-h` es `--help`, así que el
# `du -sh` de toda la vida imprimía la ayuda y salía con código 0 (fallo mudo).
# `cat`/`ls` sí se aliasan porque bat y eza aceptan los flags habituales.

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

