#!/bin/bash

# ==============================================================================
# INSTALLER SRE 2026 - Jorge Ochoa
# ==============================================================================

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🚀 Sincronizando entorno SRE...${NC}"

# 1. Detección de Sistema
OS_TYPE="$(uname)"

# 2. Instalación de Herramientas
if [ "$OS_TYPE" = "Darwin" ]; then
    echo -e "🍎 Procesando Brewfile en Mac..."
    if [ -f "$HOME/dotfiles/Brewfile" ]; then
        brew bundle --file="$HOME/dotfiles/Brewfile" || true
    fi
else
    echo -e "🐧 Instalando dependencias en Linux..."
    sudo apt update && sudo apt install -y zsh tmux git curl fzf eza bat
fi

# 3. Gestión de Enlaces Simbólicos (Symlinks)
echo -e "${BLUE}🔗 Creando Symlinks...${NC}"

# Reparar ZSH
rm -f "$HOME/.zshrc"
ln -sf "$HOME/dotfiles/zshrc" "$HOME/.zshrc"

# Reparar TMUX
rm -f "$HOME/.tmux.conf"
ln -sf "$HOME/dotfiles/tmux.conf" "$HOME/.tmux.conf"

# Reparar Starship
mkdir -p "$HOME/.config/starship"
ln -sf "$HOME/dotfiles/config/starship/starship.toml" "$HOME/.config/starship/starship.toml"

# 4. Finalización
echo -e "${GREEN}✨ ¡Configuración terminada con éxito!${NC}"
echo -e "${BLUE}Recuerda ejecutar: source ~/.zshrc${NC}"
