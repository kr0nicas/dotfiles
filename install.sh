#!/bin/bash
# ==============================================================================
# INSTALLER SRE 2026 - Jorge Ochoa (kr0nicas)
# ==============================================================================
# Automatiza el entorno para OpenClaw, SRE y desarrollo Node.js.
# Compatibilidad: macOS (Apple Silicon / Intel) + Debian + Ubuntu
#
# Uso:
#   ./install.sh             → instalación completa
#   ./install.sh --dry-run   → simula sin hacer cambios
#
# ------------------------------------------------------------------------------
# NOTA DE SEGURIDAD — Riesgo aceptado:
# Este instalador usa `curl … | bash` para varios upstream installers oficiales
# (fnm, starship, zoxide, uv, trivy, helm, claude) sin verificación de checksum.
# Es la vía oficial documentada por cada proyecto; aceptamos el trade-off por
# ergonomía. Si te preocupa supply chain:
#   1. Revisa cada URL antes de ejecutar (todos son HTTPS, hosts oficiales).
#   2. Usa --dry-run para auditar qué se descarga.
#   3. Reemplaza el bloque correspondiente por download + sha256 verificado.
# Binarios descargados desde GitHub releases (sección 6b) viajan por HTTPS
# pero tampoco verifican checksum publicado en el release.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# VARIABLES GLOBALES
# ------------------------------------------------------------------------------
FNM_VERSION="1.38.1"
FZF_VERSION="0.66.0"
DOTFILES_DIR="$HOME/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
DRY_RUN=0
INSTALL_CLOUD=1
INSTALL_K8S=1
INSTALL_GUI=1
PROFILE_FLAG=0
UPDATE_REQUESTED=0
EXISTING_INSTALL=0
DIRTY=0
REMOTE_STATUS=""

print_help() {
    cat <<'EOF'
Uso: ./install.sh [opciones]

Opciones:
  --dry-run        Simula sin hacer cambios
  --update         Si hay instalación previa: git pull --ff-only antes de re-correr
                   (aborta si hay cambios sin commit en ~/dotfiles)
  --minimal        Solo base (equivale a --no-cloud --no-k8s --no-gui)
  --vps            Perfil Servidor/VPS  (base + cloud, sin k8s ni gui)
  --container      Perfil Container/Docker (solo base, ultra-minimal)
  --k8s-node       Perfil Nodo Kubernetes (base + cloud + k8s, sin gui)
  --no-cloud       Omite Cloud/IaC (aws, azure, terraform, vault, tflint, gcloud)
  --no-k8s         Omite Kubernetes (kubectl, helm, k9s, stern, kubectx, docker)
  --no-gui         Omite apps GUI (VSCode, Brave, Spotify, Postman, ngrok)
  -h, --help       Muestra esta ayuda

Sin flags y con TTY interactivo:
  - Si detecta una instalación previa, muestra un menú de update.
  - Luego muestra el menú de perfil de instalación.

Ejemplos:
  ./install.sh                          # Menú interactivo (o full si no hay TTY)
  ./install.sh --dry-run                # Auditar sin cambios (con menú si aplica)
  ./install.sh --update                 # Pull desde git + re-aplicar configs/tools
  ./install.sh --vps                    # Servidor cloud sin k8s ni gui
  ./install.sh --container              # Dev container / Docker image
  ./install.sh --k8s-node               # Nodo de cluster Kubernetes
  ./install.sh --minimal                # Solo shell + nvim + langs
  ./install.sh --no-cloud --no-k8s      # Workstation sin SRE tools
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=1 ;;
        --update)    UPDATE_REQUESTED=1 ;;
        --minimal)   INSTALL_CLOUD=0; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --vps)       INSTALL_CLOUD=1; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --container) INSTALL_CLOUD=0; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --k8s-node)  INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --no-cloud)  INSTALL_CLOUD=0; PROFILE_FLAG=1 ;;
        --no-k8s)    INSTALL_K8S=0; PROFILE_FLAG=1 ;;
        --no-gui)    INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        -h|--help)   print_help ;;
        *)           echo "Flag desconocida: $1" >&2; echo "Usa --help para ver opciones." >&2; exit 2 ;;
    esac
    shift
done

# ------------------------------------------------------------------------------
# COLORES Y LOGGING
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BRIGHT_GREEN='\033[1;92m'
NC='\033[0m'

log()  { echo -e "${BLUE}  ℹ️  $*${NC}"; }
ok()   { echo -e "${GREEN}  ✅ $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠️  $*${NC}"; }
err()  { echo -e "${RED}  ❌ $*${NC}"; exit 1; }
section() { echo -e "\n${CYAN}━━━ $* ${NC}"; }

banner() {
    printf "\n"
    printf "%b\n" "${CYAN}██╗  ██╗██████╗ ${BRIGHT_GREEN} ██████╗ ${CYAN}███╗   ██╗██╗ ██████╗ █████╗ ███████╗${NC}"
    printf "%b\n" "${CYAN}██║ ██╔╝██╔══██╗${BRIGHT_GREEN}██╔═████╗${CYAN}████╗  ██║██║██╔════╝██╔══██╗██╔════╝${NC}"
    printf "%b\n" "${CYAN}█████╔╝ ██████╔╝${BRIGHT_GREEN}██║██╔██║${CYAN}██╔██╗ ██║██║██║     ███████║███████╗${NC}"
    printf "%b\n" "${CYAN}██╔═██╗ ██╔══██╗${BRIGHT_GREEN}████╔╝██║${CYAN}██║╚██╗██║██║██║     ██╔══██║╚════██║${NC}"
    printf "%b\n" "${CYAN}██║  ██╗██║  ██║${BRIGHT_GREEN}╚██████╔╝${CYAN}██║ ╚████║██║╚██████╗██║  ██║███████║${NC}"
    printf "%b\n" "${CYAN}╚═╝  ╚═╝╚═╝  ╚═╝${BRIGHT_GREEN} ╚═════╝ ${CYAN}╚═╝  ╚═══╝╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝${NC}"
    printf "%b\n" "              ${BRIGHT_GREEN}░ SRE 2026 · dotfiles installer ░${NC}"
    printf "\n"
}

ask_modules() {
    local r
    read -rp "  ¿Incluir Cloud/IaC (aws, terraform, gcloud)? [Y/n]: " r
    [[ "$r" =~ ^[Nn]$ ]] && INSTALL_CLOUD=0 || INSTALL_CLOUD=1
    read -rp "  ¿Incluir Kubernetes (kubectl, helm, k9s)?      [Y/n]: " r
    [[ "$r" =~ ^[Nn]$ ]] && INSTALL_K8S=0 || INSTALL_K8S=1
    read -rp "  ¿Incluir apps GUI (VSCode, Brave, Postman)?    [Y/n]: " r
    [[ "$r" =~ ^[Nn]$ ]] && INSTALL_GUI=0 || INSTALL_GUI=1
}

show_menu() {
    echo -e "${CYAN}Selecciona el perfil de instalación:${NC}"
    echo
    echo "  1) Workstation completo    (base + cloud + k8s + gui)"
    echo "  2) Servidor / VPS          (base + cloud, sin k8s ni gui)"
    echo "  3) Container / Docker      (solo base, ultra-minimal)"
    echo "  4) Nodo Kubernetes         (base + cloud + k8s, sin gui)"
    echo "  5) Personalizado           (te pregunto módulo por módulo)"
    echo "  q) Cancelar"
    echo
    local choice
    read -rp "Opción [1-5/q]: " choice
    echo
    case "$choice" in
        1)   INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=1; ok "Perfil: Workstation completo" ;;
        2)   INSTALL_CLOUD=1; INSTALL_K8S=0; INSTALL_GUI=0; ok "Perfil: Servidor / VPS" ;;
        3)   INSTALL_CLOUD=0; INSTALL_K8S=0; INSTALL_GUI=0; ok "Perfil: Container / Docker" ;;
        4)   INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=0; ok "Perfil: Nodo Kubernetes" ;;
        5)   ask_modules; ok "Perfil: Personalizado" ;;
        q|Q) echo "Cancelado."; exit 0 ;;
        *)   err "Opción inválida: '$choice'" ;;
    esac
}

detect_existing_install() {
    [[ -d "$DOTFILES_DIR/.git" ]] || return 1
    [[ -L "$HOME/.zshrc" ]] || return 1
    [[ "$(readlink "$HOME/.zshrc")" == "$DOTFILES_DIR/zshrc" ]] || return 1
    EXISTING_INSTALL=1
    return 0
}

git_status_summary() {
    local current_commit current_msg behind_count remote_commit dirty_state
    current_commit=$(git -C "$DOTFILES_DIR" rev-parse --short HEAD 2>/dev/null || echo "?")
    current_msg=$(git -C "$DOTFILES_DIR" log -1 --pretty=format:'%s' 2>/dev/null | head -c 60)

    if git -C "$DOTFILES_DIR" fetch --quiet 2>/dev/null; then
        behind_count=$(git -C "$DOTFILES_DIR" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        remote_commit=$(git -C "$DOTFILES_DIR" rev-parse --short @{u} 2>/dev/null || echo "?")
        REMOTE_STATUS="ok"
    else
        REMOTE_STATUS="offline"
        behind_count="?"
        remote_commit="?"
    fi

    if [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null)" ]]; then
        dirty_state="DIRTY (cambios sin commit)"
        DIRTY=1
    else
        dirty_state="clean"
        DIRTY=0
    fi

    echo
    echo -e "${CYAN}Instalación previa detectada:${NC}"
    echo "  Repositorio:   $DOTFILES_DIR"
    echo "  Commit actual: $current_commit  $current_msg"
    if [[ "$REMOTE_STATUS" == "ok" ]]; then
        if [[ "$behind_count" -gt 0 ]]; then
            echo -e "  Remoto:        $remote_commit  (${YELLOW}${behind_count} commits pendientes${NC})"
        else
            echo -e "  Remoto:        $remote_commit  (${GREEN}al día${NC})"
        fi
    else
        echo -e "  Remoto:        ${YELLOW}fetch falló (offline?)${NC}"
    fi
    if [[ $DIRTY -eq 1 ]]; then
        echo -e "  Estado:        ${YELLOW}${dirty_state}${NC}"
    else
        echo -e "  Estado:        ${GREEN}${dirty_state}${NC}"
    fi
    echo
}

do_git_pull() {
    if [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null)" ]]; then
        err "Hay cambios sin commit en $DOTFILES_DIR. Commitéalos primero, o re-corre sin --update (opción 2 'Re-instalar' en el menú) para saltar el git pull."
    fi
    log "git pull --ff-only en $DOTFILES_DIR..."
    if [[ $DRY_RUN -eq 1 ]]; then
        warn "DRY-RUN: git -C $DOTFILES_DIR pull --ff-only omitido"
    else
        git -C "$DOTFILES_DIR" pull --ff-only || err "git pull falló (historia divergente o conflicto). Resuelve manualmente y vuelve a correr."
        ok "Repositorio actualizado a $(git -C "$DOTFILES_DIR" rev-parse --short HEAD)"
    fi
}

show_update_menu() {
    git_status_summary
    echo "¿Qué quieres hacer?"
    echo
    echo "  1) Actualizar (git pull --ff-only + reaplicar configs/tools)"
    echo "  2) Re-instalar (saltar git pull, solo reaplicar)"
    echo "  q) Cancelar"
    echo
    local choice
    read -rp "Opción [1/2/q]: " choice
    echo
    case "$choice" in
        1)   do_git_pull ;;
        2)   ok "Saltando git pull — se re-aplicarán configs y se sincronizarán tools" ;;
        q|Q) echo "Cancelado."; exit 0 ;;
        *)   err "Opción inválida: '$choice'" ;;
    esac
}

banner
detect_existing_install || true
if [[ $UPDATE_REQUESTED -eq 1 ]]; then
    [[ $EXISTING_INSTALL -eq 1 ]] || err "--update: no se detectó instalación previa en $DOTFILES_DIR (falta .git o ~/.zshrc no apunta al repo)"
    git_status_summary
    do_git_pull
elif [[ $EXISTING_INSTALL -eq 1 && $PROFILE_FLAG -eq 0 && -t 0 ]]; then
    show_update_menu
fi
[[ $PROFILE_FLAG -eq 0 && -t 0 ]] && show_menu
[[ $DRY_RUN -eq 1 ]] && warn "Modo DRY-RUN activo — no se realizarán cambios."
log "Módulos: base=ON, cloud=$([[ $INSTALL_CLOUD -eq 1 ]] && echo ON || echo OFF), k8s=$([[ $INSTALL_K8S -eq 1 ]] && echo ON || echo OFF), gui=$([[ $INSTALL_GUI -eq 1 ]] && echo ON || echo OFF)"

# ------------------------------------------------------------------------------
# 1. DETECCIÓN DE SISTEMA Y ARQUITECTURA
# ------------------------------------------------------------------------------
section "Detección de Sistema"

OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH_TYPE="$(uname -m)"

case "$ARCH_TYPE" in
    x86_64)        ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)             ARCH="amd64" ;;
esac

if [[ "$OS_TYPE" == "darwin" ]]; then
    IS_MAC=1
    ok "macOS detectado ($ARCH)"
else
    IS_MAC=0
    OS_NAME=$(grep -oP '(?<=^ID=).+' /etc/os-release 2>/dev/null | tr -d '"' || echo "Linux")
    ok "Linux detectado: $OS_NAME ($ARCH)"
fi

[[ $DRY_RUN -eq 0 ]] && mkdir -p "$LOCAL_BIN" || { [[ -d "$LOCAL_BIN" ]] || warn "DRY-RUN: mkdir -p $LOCAL_BIN"; }

# Wrappers de scripts locales (config/bin/)
for script in "$DOTFILES_DIR/config/bin/"*; do
    [[ -f "$script" ]] || continue
    name=$(basename "$script")
    if [[ $DRY_RUN -eq 0 ]]; then
        ln -sf "$script" "$LOCAL_BIN/$name"
        chmod +x "$script"
    else
        warn "DRY-RUN: ln -sf $script → $LOCAL_BIN/$name"
    fi
done

# ------------------------------------------------------------------------------
# 2. VERIFICACIÓN DE DEPENDENCIAS CRÍTICAS
# ------------------------------------------------------------------------------
section "Verificando dependencias base"

check_deps() {
    for dep in curl git zsh; do
        if command -v "$dep" >/dev/null 2>&1; then
            ok "$dep encontrado"
        else
            err "Dependencia crítica faltante: $dep — instálala antes de continuar."
        fi
    done
}
check_deps

# ------------------------------------------------------------------------------
# 3. INSTALACIÓN DE HERRAMIENTAS BASE
# ------------------------------------------------------------------------------
section "Herramientas Base"

if [[ $IS_MAC -eq 1 ]]; then
    # Verificar licencia Xcode (solo si Xcode.app está instalado; con solo CLT no aplica)
    XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
    if [[ "$XCODE_PATH" == *"Xcode.app"* ]]; then
        if ! xcodebuild -license check &>/dev/null; then
            err "Licencia de Xcode no aceptada. Ejecuta: sudo xcodebuild -license accept"
        fi
    fi

    if command -v brew >/dev/null 2>&1; then
        # Helper local para bundle modular
        run_bundle() {
            local label=$1 file=$2 flag=$3
            if [[ $flag -eq 0 ]]; then
                warn "Skipping Brewfile${label:+.$label} (flag desactivado)"
                return
            fi
            if [[ ! -f "$file" ]]; then
                warn "No se encontró $file — omitiendo"
                return
            fi
            log "Brew bundle ${label:-base}..."
            [[ $DRY_RUN -eq 0 ]] && brew bundle --file="$file" || warn "DRY-RUN: brew bundle ${label:-base} omitido"
        }
        run_bundle "" "$DOTFILES_DIR/Brewfile"        1
        run_bundle "cloud" "$DOTFILES_DIR/Brewfile.cloud" $INSTALL_CLOUD
        run_bundle "k8s" "$DOTFILES_DIR/Brewfile.k8s"   $INSTALL_K8S
        run_bundle "gui" "$DOTFILES_DIR/Brewfile.gui"   $INSTALL_GUI
    else
        err "Homebrew no encontrado. Instálalo desde https://brew.sh"
    fi
else
    log "Actualizando apt e instalando paquetes base..."
    if [[ $DRY_RUN -eq 0 ]]; then
        sudo apt update -qq
        sudo apt install -y zsh tmux git curl jq yq ripgrep fd-find direnv age btop zstd \
            zsh-autosuggestions zsh-syntax-highlighting bsdextrautils 2>/dev/null || true

        # gh (GitHub CLI) — necesita su propio repo
        if ! command -v gh >/dev/null 2>&1; then
            log "Agregando repo GitHub CLI..."
            sudo mkdir -p /etc/apt/keyrings
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
            sudo apt update -qq && sudo apt install -y gh 2>/dev/null || warn "gh no pudo instalarse"
        fi

        # Neovim — el de apt suele ser muy viejo, usamos appimage como fallback
        NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${ARCH_TYPE}.appimage"
        if ! command -v nvim >/dev/null 2>&1; then
            log "Instalando Neovim via appimage..."
            if ! curl -fsI "$NVIM_URL" >/dev/null 2>&1; then
                warn "Neovim appimage no disponible para arch=$ARCH_TYPE ($NVIM_URL). Instala manualmente o usa el paquete del SO."
            else
                curl -fsSL -o "$LOCAL_BIN/nvim" "$NVIM_URL"
                chmod +x "$LOCAL_BIN/nvim"
                # Si appimage no funciona (FUSE no disponible), extraer
                if ! "$LOCAL_BIN/nvim" --version >/dev/null 2>&1; then
                    log "AppImage sin FUSE, extrayendo..."
                    cd /tmp && "$LOCAL_BIN/nvim" --appimage-extract >/dev/null 2>&1
                    rm -f "$LOCAL_BIN/nvim"
                    mv /tmp/squashfs-root "$HOME/.local/nvim-squashfs"
                    ln -sf "$HOME/.local/nvim-squashfs/usr/bin/nvim" "$LOCAL_BIN/nvim"
                    cd -
                fi
                ok "Neovim instalado: $($LOCAL_BIN/nvim --version | head -1)"
            fi
        else
            NVIM_VER=$(nvim --version | head -1 | grep -oP '\d+\.\d+')
            if (( $(echo "$NVIM_VER < 0.10" | bc -l) )); then
                warn "Neovim $NVIM_VER es muy viejo (se necesita >=0.10). Actualizando..."
                if ! curl -fsI "$NVIM_URL" >/dev/null 2>&1; then
                    warn "Neovim appimage no disponible para arch=$ARCH_TYPE — actualiza manualmente."
                else
                    curl -fsSL -o "$LOCAL_BIN/nvim" "$NVIM_URL"
                    chmod +x "$LOCAL_BIN/nvim"
                    if ! "$LOCAL_BIN/nvim" --version >/dev/null 2>&1; then
                        cd /tmp && "$LOCAL_BIN/nvim" --appimage-extract >/dev/null 2>&1
                        rm -f "$LOCAL_BIN/nvim"
                        mv /tmp/squashfs-root "$HOME/.local/nvim-squashfs"
                        ln -sf "$HOME/.local/nvim-squashfs/usr/bin/nvim" "$LOCAL_BIN/nvim"
                        cd -
                    fi
                    ok "Neovim actualizado: $($LOCAL_BIN/nvim --version | head -1)"
                fi
            fi
        fi

        # fd → symlink fdfind si hace falta
        if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
            ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
            ok "Symlink fd → fdfind creado"
        fi

        # eza (no está en apt por defecto)
        if ! command -v eza >/dev/null 2>&1; then
            log "Instalando eza..."
            sudo mkdir -p /etc/apt/keyrings
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main" \
                | sudo tee /etc/apt/sources.list.d/gierens.list
            sudo apt update -qq && sudo apt install -y eza 2>/dev/null || warn "eza no pudo instalarse"
        fi

        # bat → symlink batcat si hace falta
        if ! command -v bat >/dev/null 2>&1; then
            sudo apt install -y bat 2>/dev/null || true
            if command -v batcat >/dev/null 2>&1 && [[ ! -f "$LOCAL_BIN/bat" ]]; then
                ln -sf /usr/bin/batcat "$LOCAL_BIN/bat"
                ok "Symlink bat → batcat creado"
            fi
        fi
    else
        warn "DRY-RUN: apt install omitido"
    fi
fi

# ------------------------------------------------------------------------------
# 4. FNM + NODE.JS LTS
# ------------------------------------------------------------------------------
section "fnm v$FNM_VERSION + Node.js LTS"

if ! command -v fnm >/dev/null 2>&1; then
    log "Instalando fnm v$FNM_VERSION..."
    if [[ $DRY_RUN -eq 0 ]]; then
        curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$LOCAL_BIN" --skip-shell
        export PATH="$LOCAL_BIN:$PATH"
        eval "$(fnm env --shell bash)"
        fnm install --lts && fnm use lts-latest
        ok "fnm + Node.js LTS instalados"
    else
        warn "DRY-RUN: fnm install omitido"
    fi
else
    ok "fnm ya instalado ($(fnm --version))"
    if [[ $DRY_RUN -eq 0 ]]; then
        fnm install --lts 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------------------
# 5. FZF v$FZF_VERSION
# ------------------------------------------------------------------------------
section "fzf v$FZF_VERSION"

CURRENT_FZF="$(fzf --version 2>/dev/null | awk '{print $1}' || echo '')"

if [[ "$CURRENT_FZF" != "$FZF_VERSION" ]]; then
    log "Instalando fzf v$FZF_VERSION (actual: ${CURRENT_FZF:-ninguna})..."
    FZF_URL="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${OS_TYPE}_${ARCH}.tar.gz"
    if [[ $DRY_RUN -eq 0 ]]; then
        curl -fsSL "$FZF_URL" | tar -xz -C "$LOCAL_BIN"
        ok "fzf v$FZF_VERSION instalado en $LOCAL_BIN"
    else
        warn "DRY-RUN: fzf install omitido ($FZF_URL)"
    fi
else
    ok "fzf ya está en v$FZF_VERSION"
fi

# ------------------------------------------------------------------------------
# 6. STARSHIP, ZOXIDE, UV (si no vienen del Brewfile/apt)
# ------------------------------------------------------------------------------
section "Starship · Zoxide · uv"

install_if_missing() {
    local cmd=$1 install_cmd=$2
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "Instalando $cmd..."
        if [[ $DRY_RUN -eq 0 ]]; then
            eval "$install_cmd" || warn "$cmd no pudo instalarse, continúa manualmente."
        else
            warn "DRY-RUN: $cmd install omitido"
        fi
    else
        ok "$cmd ya instalado ($(command -v $cmd))"
    fi
}

install_if_missing "starship" "curl -sS https://starship.rs/install.sh | sh -s -- --yes"
install_if_missing "zoxide"   "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"
install_if_missing "uv"       "curl -LsSf https://astral.sh/uv/install.sh | sh"

# ------------------------------------------------------------------------------
# 6b. HERRAMIENTAS SRE (binarios — solo Linux, en Mac vienen del Brewfile)
# ------------------------------------------------------------------------------
if [[ $IS_MAC -eq 0 ]]; then
    section "Herramientas SRE (Linux)"

    # Mapeo de arquitectura para proyectos que usan x86_64/arm64
    case "$ARCH_TYPE" in
        x86_64)  GH_ARCH="x86_64" ;;
        aarch64) GH_ARCH="arm64"   ;;
        arm64)   GH_ARCH="arm64"   ;;
        *)       GH_ARCH="x86_64"  ;;
    esac

    # Helper: descarga el último release de GitHub sin hardcodear versión
    # Compatible con Linux y macOS (sin grep -P)
    # Detecta rate-limit (60 req/h anónimo) y emite warning legible.
    gh_latest_url() {
        local repo=$1 pattern=$2
        local response
        response=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null) || {
            warn "GitHub API falló para $repo (¿rate-limit? auth con: gh auth login). Saltando."
            return 1
        }
        if [[ "$response" == *"API rate limit exceeded"* ]] || [[ "$response" == *"rate limit"* ]]; then
            warn "GitHub API rate-limit alcanzado (60 req/h anónimo). Auth: gh auth login. Saltando $repo."
            return 1
        fi
        printf '%s\n' "$response" \
            | grep "browser_download_url" | grep "$pattern" | head -1 \
            | sed 's/.*"browser_download_url": *"//;s/".*//'
    }

    gh_latest_tar() {
        local repo=$1 pattern=$2 dest=$3 extra_tar_args=${4:-}
        local url
        url=$(gh_latest_url "$repo" "$pattern")
        if [[ -n "$url" ]]; then
            curl -fsSL "$url" | tar -xz -C "$dest" $extra_tar_args
        else
            return 1
        fi
    }

    # --- Always: dev ergonomics + security (no gating) ---
    install_if_missing "lazygit" \
        "gh_latest_tar jesseduffield/lazygit 'linux_${GH_ARCH}.tar.gz' $LOCAL_BIN lazygit"

    install_if_missing "delta" \
        "gh_latest_tar dandavison/delta '${GH_ARCH}-unknown-linux-gnu.tar.gz' $LOCAL_BIN '--strip-components=1 --wildcards */delta'"

    install_if_missing "trivy" \
        "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $LOCAL_BIN"

    install_if_missing "sops" \
        "gh_latest_url getsops/sops 'linux.${ARCH}' | xargs -I{} curl -fsSL -o $LOCAL_BIN/sops {} && chmod +x $LOCAL_BIN/sops"

    install_if_missing "dust" \
        "gh_latest_tar bootandy/dust '${GH_ARCH}-unknown-linux-gnu.tar.gz' $LOCAL_BIN '--strip-components=1 --wildcards */dust'"

    install_if_missing "curlie" \
        "gh_latest_tar rs/curlie 'linux_${ARCH}.tar.gz' $LOCAL_BIN curlie"

    # --- K8s tools (gated por --no-k8s / --minimal) ---
    if [[ $INSTALL_K8S -eq 1 ]]; then
        install_if_missing "k9s" \
            "gh_latest_tar derailed/k9s 'Linux_${ARCH}.tar.gz' $LOCAL_BIN k9s"

        install_if_missing "stern" \
            "gh_latest_tar stern/stern 'linux_${ARCH}.tar.gz' $LOCAL_BIN stern"
    else
        warn "Skipping k9s/stern (--no-k8s)"
    fi

    install_jless() {
        local url
        url=$(gh_latest_url PaulJuliusMartinez/jless "${GH_ARCH}-unknown-linux-gnu.zip")
        if [[ -n "$url" ]]; then
            curl -fsSL "$url" -o /tmp/jless.zip && unzip -qo /tmp/jless.zip -d "$LOCAL_BIN" && rm -f /tmp/jless.zip
            chmod +x "$LOCAL_BIN/jless"
        else
            return 1
        fi
    }
    install_if_missing "jless" "install_jless"

    # --- K8s core (gated por --no-k8s / --minimal) ---
    if [[ $INSTALL_K8S -eq 1 ]]; then
        # kubectl — latest stable
        if ! command -v kubectl >/dev/null 2>&1; then
            log "Instalando kubectl..."
            if [[ $DRY_RUN -eq 0 ]]; then
                KUBECTL_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
                curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${ARCH}/kubectl" \
                    -o "$LOCAL_BIN/kubectl" && chmod +x "$LOCAL_BIN/kubectl" \
                    && ok "kubectl ${KUBECTL_VER} instalado" \
                    || warn "kubectl no pudo instalarse, continúa manualmente."
            else
                warn "DRY-RUN: kubectl install omitido"
            fi
        else
            ok "kubectl ya instalado ($(kubectl version --client --short 2>/dev/null | head -1))"
        fi

        # helm — latest stable
        if ! command -v helm >/dev/null 2>&1; then
            log "Instalando helm..."
            if [[ $DRY_RUN -eq 0 ]]; then
                curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
                    && ok "helm instalado" \
                    || warn "helm no pudo instalarse, continúa manualmente."
            else
                warn "DRY-RUN: helm install omitido"
            fi
        else
            ok "helm ya instalado ($(helm version --short 2>/dev/null))"
        fi

        # kubectx / kubens
        if ! command -v kubectx >/dev/null 2>&1; then
            log "Instalando kubectx/kubens..."
            if [[ $DRY_RUN -eq 0 ]]; then
                gh_latest_tar ahmetb/kubectx "kubectx_v.*_linux_${GH_ARCH}.tar.gz" "$LOCAL_BIN" kubectx \
                    || warn "kubectx no pudo instalarse, continúa manualmente."
                gh_latest_tar ahmetb/kubectx "kubens_v.*_linux_${GH_ARCH}.tar.gz" "$LOCAL_BIN" kubens \
                    || warn "kubens no pudo instalarse, continúa manualmente."
                command -v kubectx >/dev/null 2>&1 && ok "kubectx/kubens instalados"
            else
                warn "DRY-RUN: kubectx install omitido"
            fi
        else
            ok "kubectx ya instalado"
        fi
    else
        warn "Skipping kubectl/helm/kubectx (--no-k8s)"
    fi

    # --- Cloud / IaC (gated por --no-cloud / --minimal) ---
    if [[ $INSTALL_CLOUD -eq 1 ]]; then
        # OpenTofu — latest stable (reemplazo open source de Terraform)
        if ! command -v tofu >/dev/null 2>&1; then
            log "Instalando OpenTofu..."
            if [[ $DRY_RUN -eq 0 ]]; then
                TOFU_VER=$(curl -fsSL https://api.github.com/repos/opentofu/opentofu/releases/latest \
                    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
                TOFU_URL="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VER}/tofu_${TOFU_VER}_linux_${ARCH}.tar.gz"
                curl -fsSL "$TOFU_URL" | tar -xz -C "$LOCAL_BIN" tofu \
                    && ok "OpenTofu v${TOFU_VER} instalado" \
                    || warn "OpenTofu no pudo instalarse, continúa manualmente."
            else
                warn "DRY-RUN: OpenTofu install omitido"
            fi
        else
            ok "OpenTofu ya instalado ($(tofu version | head -1))"
        fi
    else
        warn "Skipping OpenTofu (--no-cloud)"
    fi
fi

# ------------------------------------------------------------------------------
# 7. TMUX — TPM Y PLUGINS
# ------------------------------------------------------------------------------
section "Tmux Plugin Manager (TPM)"

TPM_DIR="$HOME/.tmux/plugins/tpm"

if [[ ! -d "$TPM_DIR" ]]; then
    log "Instalando TPM..."
    if [[ $DRY_RUN -eq 0 ]]; then
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" --depth=1
        ok "TPM instalado en $TPM_DIR"
    else
        warn "DRY-RUN: TPM install omitido"
    fi
else
    ok "TPM ya instalado en $TPM_DIR"
    if [[ $DRY_RUN -eq 0 ]]; then
        git -C "$TPM_DIR" pull --rebase --quiet && ok "TPM actualizado" || warn "TPM update falló, continúa..."
    fi
fi

# ------------------------------------------------------------------------------
# 8. NEOVIM — LAZY.NVIM (bootstrap automático al abrir nvim)
# ------------------------------------------------------------------------------
section "Neovim"

if command -v nvim >/dev/null 2>&1; then
    ok "Neovim encontrado: $(nvim --version | head -1)"
else
    warn "Neovim no encontrado — instálalo manualmente si brew/apt falló"
fi

# ------------------------------------------------------------------------------
# 8b. CLAUDE CODE — build nativo (independiente de fnm/npm)
# ------------------------------------------------------------------------------
# Evita perder `claude` del PATH cuando fnm cambia de versión de node al entrar
# a un proyecto con .nvmrc/.node-version. El build nativo vive en ~/.local/bin
# y no depende de la versión activa de node.
section "Claude Code (native build)"

if [[ -d "$HOME/.local/share/claude" ]]; then
    ok "Claude Code nativo ya activo ($HOME/.local/bin/claude)"
elif command -v claude >/dev/null 2>&1; then
    log "Detectado claude vía npm/fnm — migrando a build nativo..."
    if [[ $DRY_RUN -eq 0 ]]; then
        if claude install stable --force >/dev/null 2>&1; then
            ok "Migrado a build nativo en ~/.local/bin/claude"
        else
            warn "Migración falló — corre manualmente: claude install stable --force"
        fi
    else
        warn "DRY-RUN: claude install stable --force omitido"
    fi
else
    if [[ $DRY_RUN -eq 0 ]]; then
        log "Instalando Claude Code nativo..."
        if curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; then
            ok "Claude Code instalado en ~/.local/bin/claude"
        else
            warn "Instalación falló — manual: curl -fsSL https://claude.ai/install.sh | bash"
        fi
    else
        warn "DRY-RUN: instalación de claude omitida"
    fi
fi

# ------------------------------------------------------------------------------
# 9. SYMLINKS DE DOTFILES
# ------------------------------------------------------------------------------
section "Sincronizando Symlinks"

safe_link() {
    local src=$1 dest=$2
    if [[ ! -f "$src" ]]; then
        warn "Fuente no encontrada, omitiendo: $src"
        return
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        warn "DRY-RUN: ln -sf $src → $dest"
        return
    fi
    # Si el destino ya existe y NO es symlink al mismo src, respaldar antes de pisar
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
            : # ya apunta al repo, nada que hacer
        elif [[ -L "$dest" ]]; then
            rm -f "$dest"
        else
            local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
            mv "$dest" "$backup"
            warn "Config existente respaldada: $backup"
        fi
    fi
    ln -sf "$src" "$dest"
    ok "Linked: $dest → $src"
}

safe_mkdir() {
    local dir=$1
    if [[ $DRY_RUN -eq 1 ]]; then
        [[ -d "$dir" ]] || warn "DRY-RUN: mkdir -p $dir"
        return
    fi
    mkdir -p "$dir"
}

safe_mkdir "$HOME/.config"

safe_link "$DOTFILES_DIR/zshrc"                         "$HOME/.zshrc"
safe_link "$DOTFILES_DIR/tmux.conf"                     "$HOME/.tmux.conf"
safe_link "$DOTFILES_DIR/.gitconfig"                    "$HOME/.gitconfig"
safe_link "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"

# SSH color map (override local posible: ~/.ssh/colors.conf, sin symlink)
if [[ -f "$DOTFILES_DIR/config/ssh/colors.conf" ]]; then
    safe_mkdir "$HOME/.ssh"
    [[ $DRY_RUN -eq 0 ]] && chmod 700 "$HOME/.ssh"
    safe_link "$DOTFILES_DIR/config/ssh/colors.conf" "$HOME/.ssh/colors.conf"
fi

# Claude Code settings + statusline
if [[ -f "$DOTFILES_DIR/config/claude/settings.json" ]]; then
    safe_mkdir "$HOME/.claude"
    safe_link "$DOTFILES_DIR/config/claude/settings.json" "$HOME/.claude/settings.json"
    safe_link "$DOTFILES_DIR/config/claude/statusline.sh"  "$HOME/.claude/statusline.sh"

    # settings.local.json: overrides por máquina (no versionado). Sembrar desde example si falta.
    if [[ ! -e "$HOME/.claude/settings.local.json" ]]; then
        if [[ $DRY_RUN -eq 0 ]]; then
            cp "$DOTFILES_DIR/config/claude/settings.local.json.example" "$HOME/.claude/settings.local.json"
            ok "Sembrado: ~/.claude/settings.local.json (edítalo para overrides locales)"
        else
            warn "DRY-RUN: sembraría ~/.claude/settings.local.json"
        fi
    fi
fi

# rtk (Rust Token Killer) config — ruta de config difiere por OS.
# El hook de Claude Code se registra aparte con: rtk init -g --hook-only
if [[ -f "$DOTFILES_DIR/config/rtk/config.toml" ]]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        RTK_CFG_DIR="$HOME/Library/Application Support/rtk"
    else
        RTK_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rtk"
    fi
    safe_mkdir "$RTK_CFG_DIR"
    safe_link "$DOTFILES_DIR/config/rtk/config.toml" "$RTK_CFG_DIR/config.toml"
fi

# WezTerm config
if [[ -f "$DOTFILES_DIR/config/wezterm/wezterm.lua" ]]; then
    if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
        # WSL2: el symlink debe vivir en el lado Windows (~/.config/wezterm/)
        # WezTerm corre como app Windows y no ve el filesystem de WSL directamente
        WIN_HOME=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n')
        WIN_CONFIG="$WIN_HOME\\.config\\wezterm"
        WIN_SRC=$(wslpath -w "$DOTFILES_DIR/config/wezterm/wezterm.lua")
        WIN_DEST="$WIN_CONFIG\\wezterm.lua"

        if [[ -n "$WIN_HOME" ]] && [[ $DRY_RUN -eq 0 ]]; then
            powershell.exe -NoProfile -Command "
                \$dest = '$WIN_DEST'
                \$src  = '$WIN_SRC'
                New-Item -ItemType Directory -Force -Path (Split-Path \$dest) | Out-Null
                if (Test-Path \$dest) { Remove-Item \$dest -Force }
                New-Item -ItemType SymbolicLink -Path \$dest -Target \$src | Out-Null
                Write-Host 'Linked (Windows): ' + \$dest
            " 2>/dev/null \
            && ok "Linked (Windows): $WIN_DEST → $WIN_SRC" \
            || warn "Symlink Windows requiere Modo Desarrollador o PowerShell como Admin — copia manual: cp $DOTFILES_DIR/config/wezterm/wezterm.lua $(wslpath "$WIN_HOME")/.config/wezterm/wezterm.lua"
        elif [[ $DRY_RUN -eq 1 ]]; then
            warn "DRY-RUN: New-Item SymbolicLink $WIN_DEST → $WIN_SRC"
        fi
    else
        # macOS / Linux nativo
        safe_mkdir "$HOME/.config/wezterm"
        safe_link "$DOTFILES_DIR/config/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
    fi
fi

# direnv config directory
if [[ -d "$DOTFILES_DIR/config/direnv" ]]; then
    safe_mkdir "$HOME/.config/direnv"
    safe_link "$DOTFILES_DIR/config/direnv/direnv.toml" "$HOME/.config/direnv/direnv.toml"
fi

# Neovim config directory
if [[ -d "$DOTFILES_DIR/config/nvim" ]]; then
    if [[ $DRY_RUN -eq 0 ]]; then
        # Si ya existe un dir real (no symlink al repo), respaldar antes de pisar
        if [[ -e "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
            BACKUP="$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)"
            mv "$HOME/.config/nvim" "$BACKUP"
            warn "Config existente respaldada en: $BACKUP"
        elif [[ -L "$HOME/.config/nvim" ]]; then
            rm -f "$HOME/.config/nvim"
        fi
        ln -sf "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"
        ok "Linked: ~/.config/nvim → $DOTFILES_DIR/config/nvim"
    else
        warn "DRY-RUN: ln -sf $DOTFILES_DIR/config/nvim → ~/.config/nvim (con backup automático si aplica)"
    fi
fi

# Instalar plugins de Neovim headless (lazy.nvim bootstrap)
if command -v nvim >/dev/null 2>&1 && [[ -d "$HOME/.config/nvim" && $DRY_RUN -eq 0 ]]; then
    log "Instalando plugins Neovim (lazy.nvim sync)..."
    nvim --headless -c 'lua require("lazy").sync({ wait = true })' -c 'qa' 2>/dev/null \
        && ok "Plugins Neovim instalados" \
        || warn "Plugins no instalados headless — abre nvim y lazy.nvim los descargará"
fi

# ------------------------------------------------------------------------------
# 10. LIMPIEZA DE CACHÉ ZSH
# ------------------------------------------------------------------------------
section "Limpieza"

if [[ $DRY_RUN -eq 0 ]]; then
    rm -f "$HOME"/.zcompdump* 2>/dev/null || true
    ok "Caché zsh limpiado"
else
    warn "DRY-RUN: limpieza omitida"
fi

# ------------------------------------------------------------------------------
# 11. RESUMEN FINAL
# ------------------------------------------------------------------------------
section "Resumen de instalación"

echo ""
printf "  %-14s %-30s %s\n" "HERRAMIENTA" "RUTA" "ESTADO"
printf "  %-14s %-30s %s\n" "──────────" "────────────────────────────" "──────"
for t in zsh git curl fzf node npm uv starship zoxide eza bat gh tmux nvim rg fd k9s kubectl helm stern kubectx lazygit direnv delta trivy tofu docker dust btop curlie jless jq yq zstd; do
    path_t=$(command -v "$t" 2>/dev/null || echo "—")
    status=$([[ "$path_t" != "—" ]] && echo "✅" || echo "❌")
    printf "  %-14s %-30s %s\n" "$t" "$path_t" "$status"
done

# Estado TPM y lazy.nvim
tpm_status=$([[ -d "$HOME/.tmux/plugins/tpm" ]] && echo "✅" || echo "❌")
lazy_status=$([[ -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ]] && echo "✅" || echo "❌")
printf "  %-14s %-30s %s\n" "tpm"       "$HOME/.tmux/plugins/tpm"                "$tpm_status"
printf "  %-14s %-30s %s\n" "lazy.nvim" "$HOME/.local/share/nvim/lazy/lazy.nvim"  "$lazy_status"
echo ""

ok "¡Entorno SRE 2026 listo!"
warn "Ejecuta: source ~/.zshrc"
