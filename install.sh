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
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# VARIABLES GLOBALES
# ------------------------------------------------------------------------------
NVM_VERSION="v0.40.1"
FZF_VERSION="0.66.0"
DOTFILES_DIR="$HOME/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
DRY_RUN=0

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# ------------------------------------------------------------------------------
# COLORES Y LOGGING
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${BLUE}  ℹ️  $*${NC}"; }
ok()   { echo -e "${GREEN}  ✅ $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠️  $*${NC}"; }
err()  { echo -e "${RED}  ❌ $*${NC}"; exit 1; }
section() { echo -e "\n${CYAN}━━━ $* ${NC}"; }

[[ $DRY_RUN -eq 1 ]] && warn "Modo DRY-RUN activo — no se realizarán cambios."

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

mkdir -p "$LOCAL_BIN"

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
    # Verificar licencia Xcode
    if ! xcodebuild -license check &>/dev/null 2>&1; then
        err "Licencia de Xcode no aceptada. Ejecuta: sudo xcodebuild -license accept"
    fi

    if command -v brew >/dev/null 2>&1; then
        if [[ -f "$DOTFILES_DIR/Brewfile" ]]; then
            log "Instalando desde Brewfile..."
            [[ $DRY_RUN -eq 0 ]] && brew bundle --file="$DOTFILES_DIR/Brewfile" || warn "DRY-RUN: brew bundle omitido"
        else
            warn "No se encontró Brewfile en $DOTFILES_DIR"
            log "Instalando herramientas base con Homebrew..."
            if [[ $DRY_RUN -eq 0 ]]; then
                brew install git zsh curl eza bat vim gh fzf zoxide starship uv || true
            else
                warn "DRY-RUN: brew install omitido"
            fi
        fi
    else
        err "Homebrew no encontrado. Instálalo desde https://brew.sh"
    fi
else
    log "Actualizando apt e instalando paquetes base..."
    if [[ $DRY_RUN -eq 0 ]]; then
        sudo apt update -qq
        sudo apt install -y zsh tmux git curl vim gh 2>/dev/null || true

        # eza (no está en apt por defecto)
        if ! command -v eza >/dev/null 2>&1; then
            log "Instalando eza..."
            sudo mkdir -p /etc/apt/keyrings
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
            echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
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
# 4. NVM + NODE.JS LTS
# ------------------------------------------------------------------------------
section "NVM $NVM_VERSION + Node.js LTS"

export NVM_DIR="$HOME/.nvm"

if [[ ! -d "$NVM_DIR" ]]; then
    log "Instalando NVM $NVM_VERSION..."
    if [[ $DRY_RUN -eq 0 ]]; then
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
        [[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        nvm use --lts
        ok "NVM + Node.js LTS instalados"
    else
        warn "DRY-RUN: NVM install omitido"
    fi
else
    ok "NVM ya instalado en $NVM_DIR"
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
# 7. SYMLINKS DE DOTFILES
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
    rm -f "$dest"
    ln -sf "$src" "$dest"
    ok "Linked: $dest → $src"
}

mkdir -p "$HOME/.config"

safe_link "$DOTFILES_DIR/zshrc"         "$HOME/.zshrc"
safe_link "$DOTFILES_DIR/tmux.conf"     "$HOME/.tmux.conf"
safe_link "$DOTFILES_DIR/vimrc"         "$HOME/.vimrc"
safe_link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"

# ------------------------------------------------------------------------------
# 8. LIMPIEZA DE CACHÉ ZSH
# ------------------------------------------------------------------------------
section "Limpieza"

if [[ $DRY_RUN -eq 0 ]]; then
    rm -f "$HOME"/.zcompdump* 2>/dev/null || true
    ok "Caché zsh limpiado"
else
    warn "DRY-RUN: limpieza omitida"
fi

# ------------------------------------------------------------------------------
# 9. RESUMEN FINAL
# ------------------------------------------------------------------------------
section "Resumen de instalación"

echo ""
printf "  %-14s %-30s %s\n" "HERRAMIENTA" "RUTA" "ESTADO"
printf "  %-14s %-30s %s\n" "──────────" "────────────────────────────" "──────"
for t in zsh git curl fzf node npm uv starship zoxide eza bat gh tmux vim; do
    path_t=$(command -v "$t" 2>/dev/null || echo "—")
    status=$([[ "$path_t" != "—" ]] && echo "✅" || echo "❌")
    printf "  %-14s %-30s %s\n" "$t" "$path_t" "$status"
done
echo ""

ok "¡Entorno SRE 2026 listo!"
warn "Ejecuta: source ~/.zshrc"
