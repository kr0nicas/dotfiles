#!/bin/bash

# ==============================================================================
# INSTALLER SRE 2026 - Jorge Ochoa (kr0nicas)
# ==============================================================================
# Automatiza el entorno para OpenClaw y SRE.
# Basado en: https://junegunn.github.io/fzf/installation/
# Versión: 0.66.0

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

# Mapeo de Arquitectura
case "$ARCH_TYPE" in
    x86_64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)       ARCH="amd64" ;;
esac

# 2. Instalación de Herramientas Base
if [ "$OS_TYPE" = "darwin" ]; then
    echo -e "${BLUE}🍎 Sistema detectado: macOS ($ARCH)${NC}"
    
    # Validación de Licencia de Xcode (SRE Check)
    if command -v xcodebuild >/dev/null; then
        if ! xcodebuild -license check &>/dev/null; then
            echo -e "${RED}⚠️ Error: No has aceptado la licencia de Xcode.${NC}"
            echo -e "${YELLOW}Por favor, ejecuta: sudo xcodebuild -license accept${NC}"
            echo -e "${YELLOW}Luego vuelve a ejecutar este instalador.${NC}"
            exit 1
        fi
    fi

    if command -v brew >/dev/null; then
        if [ -f "$DOTFILES_DIR/Brewfile" ]; then
            echo -e "📦 Procesando Brewfile..."
            brew bundle --file="$DOTFILES_DIR/Brewfile" || true
        fi
    else
        echo -e "${RED}⚠️ Homebrew no detectado. Instálalo primero en https://brew.sh${NC}"
    fi
else
    echo -e "${BLUE}🐧 Sistema detectado: Linux ($ARCH)${NC}"
    sudo apt update && sudo apt install -y zsh tmux git curl eza bat vim 2>/dev/null || true
    
    # Fix para 'bat' en Ubuntu
    if command -v batcat >/dev/null && [ ! -f "$LOCAL_BIN/bat" ]; then
        ln -sf /usr/bin/batcat "$LOCAL_BIN/bat"
    fi
fi

# 3. Instalación/Actualización Pro de fzf (v0.66.0)
FZF_TARGET="0.66.0"
echo -e "🔍 Verificando fzf $FZF_TARGET..."

CURRENT_FZF_VER=$(fzf --version 2>/dev/null | awk '{print $1}')

if [[ "$CURRENT_FZF_VER" != "$FZF_TARGET" ]]; then
    echo -e "${YELLOW}📦 Instalando binario oficial de fzf v$FZF_TARGET ($OS_TYPE/$ARCH)...${NC}"
    
    FZF_URL="https://github.com/junegunn/fzf/releases/download/v${FZF_TARGET}/fzf-${FZF_TARGET}-${OS_TYPE}_${ARCH}.tar.gz"
    
    if curl -fsSL "$FZF_URL" | tar -xz -C "$LOCAL_BIN"; then
        echo -e "${GREEN}✅ fzf $FZF_TARGET instalado en $LOCAL_BIN${NC}"
    else
        echo -e "${RED}❌ Falló la descarga de fzf. Verificando URL...${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ fzf ya está actualizado en la versión $FZF_TARGET${NC}"
fi

# 4. Limpieza de ZSH para evitar errores de "nesting" o "unknown option"
echo -e "${BLUE}🧹 Limpiando caché de autocompletado...${NC}"
rm -f "$HOME/.zcompdump*" 2>/dev/null

# 5. Reparación de Symlinks
echo -e "${BLUE}🔗 Sincronizando Symlinks...${NC}"

safe_link() {
    local src=$1
    local dest=$2
    if [ -f "$src" ]; then
        rm -f "$dest"
        ln -sf "$src" "$dest"
        echo -e "${GREEN}✅ Linked: $dest${NC}"
    else
        echo -e "${RED}⚠️ No se encontró la fuente: $src${NC}"
    fi
}

# Symlinks principales (ZSH & TMUX)
[[ -f "$DOTFILES_DIR/.zshrc" ]] && safe_link "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc" || safe_link "$DOTFILES_DIR/zshrc" "$HOME/.zshrc"
[[ -f "$DOTFILES_DIR/.tmux.conf" ]] && safe_link "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf" || safe_link "$DOTFILES_DIR/tmux.conf" "$HOME/.tmux.conf"

# Symlink Vim (Mejorado para buscar ambas variantes)
if [ -f "$DOTFILES_DIR/.vimrc" ]; then
    safe_link "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
elif [ -f "$DOTFILES_DIR/vimrc" ]; then
    safe_link "$DOTFILES_DIR/vimrc" "$HOME/.vimrc"
else
    echo -e "${RED}❌ No se encontró vimrc en el repositorio.${NC}"
fi

# Symlink Starship
mkdir -p "$HOME/.config"
if [ -f "$DOTFILES_DIR/starship.toml" ]; then
    safe_link "$DOTFILES_DIR/starship.toml" "$HOME/.config/starship.toml"
elif [ -f "$DOTFILES_DIR/config/starship/starship.toml" ]; then
    safe_link "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
else
    echo -e "${RED}❌ No se encontró starship.toml en el repositorio.${NC}"
fi

# 6. Finalización
echo -e "${GREEN}✨ ¡Entorno SRE normalizado!${NC}"
echo -e "${YELLOW}👉 Ejecuta: source ~/.zshrc${NC}"

