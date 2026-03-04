#!/bin/bash

# ==============================================================================
# INSTALLER SRE 2026 - Jorge Ochoa (kr0nicas)
# ==============================================================================
# Automatiza el entorno para OpenClaw, SRE y desarrollo Node.js.
# Basado en: https://junegunn.github.io/fzf/installation/
# Incluye: NVM v0.40.1 + Node.js LTS
# Versión fzf: 0.66.0

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Iniciando sincronización de entorno SRE para Jorge Ochoa...${NC}"

# 1. Detección de Sistema y Arquitectura
OS_TYPE="$(uname | tr '[:upper:]' '[:lower:]')"
ARCH_TYPE="$(uname -m)"
DOTFILES_DIR="$HOME/dotfiles"
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

case "$ARCH_TYPE" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)       ARCH="amd64" ;;
esac

# 2. Instalación de Herramientas Base
if [ "$OS_TYPE" = "darwin" ]; then
    echo -e "${BLUE}🍎 Sistema detectado: macOS ($ARCH)${NC}"
    if command -v xcodebuild >/dev/null && ! xcodebuild -license check &>/dev/null; then
        echo -e "${RED}⚠️ Por favor, ejecuta: sudo xcodebuild -license accept${NC}"; exit 1
    fi
    if command -v brew >/dev/null; then
        [ -f "$DOTFILES_DIR/Brewfile" ] && brew bundle --file="$DOTFILES_DIR/Brewfile" || true
    fi
else
    echo -e "${BLUE}🐧 Sistema detectado: Linux ($ARCH)${NC}"
    sudo apt update && sudo apt install -y zsh tmux git curl eza bat vim 2>/dev/null || true
    if command -v batcat >/dev/null && [ ! -f "$LOCAL_BIN/bat" ]; then
        ln -sf /usr/bin/batcat "$LOCAL_BIN/bat"
    fi
fi

# 3. Instalación de NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    echo -e "${YELLOW}📦 Instalando NVM v0.40.1...${NC}"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    # Cargar NVM temporalmente para instalar Node inmediatamente
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    echo -e "${GREEN}✅ NVM instalado. Instalando Node.js LTS...${NC}"
    nvm install --lts
    nvm use --lts
else
    echo -e "${GREEN}✅ NVM ya está instalado en $NVM_DIR${NC}"
fi

# 4. Instalación/Actualización Pro de fzf (v0.66.0)
FZF_TARGET="0.66.0"
CURRENT_FZF_VER=$(fzf --version 2>/dev/null | awk '{print $1}')

if [[ "$CURRENT_FZF_VER" != "$FZF_TARGET" ]]; then
    echo -e "${YELLOW}📦 Actualizando fzf a v$FZF_TARGET...${NC}"
    FZF_URL="https://github.com/junegunn/fzf/releases/download/v${FZF_TARGET}/fzf-${FZF_TARGET}-${OS_TYPE}_${ARCH}.tar.gz"
    curl -fsSL "$FZF_URL" | tar -xz -C "$LOCAL_BIN"
fi

# 5. Limpieza y Symlinks
echo -e "${BLUE}🧹 Limpiando caché y sincronizando Symlinks...${NC}"
rm -f "$HOME/.zcompdump*" 2>/dev/null

safe_link() {
    local src=$1 dest=$2
    if [ -f "$src" ]; then rm -f "$dest"; ln -sf "$src" "$dest"; echo -e "${GREEN}✅ Linked: $dest${NC}"; fi
}

[[ -f "$DOTFILES_DIR/zshrc" ]] && safe_link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
[[ -f "$DOTFILES_DIR/tmux.conf" ]] && safe_link "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"
[[ -f "$DOTFILES_DIR/vimrc" ]] && safe_link "$DOTFILES_DIR/vimrc" "$HOME/.vimrc"

mkdir -p "$HOME/.config"
[ -f "$DOTFILES_DIR/starship.toml" ] && safe_link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"

echo -e "${GREEN}✨ ¡Entorno SRE con Node.js normalizado!${NC}"
echo -e "${YELLOW}👉 Ejecuta: source ~/.zshrc${NC}"
