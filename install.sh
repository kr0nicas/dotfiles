#!/bin/bash

# ==============================================================================
# INSTALLER SRE 2026 - MULTI-PLATFORM (BASH)
# ==============================================================================

set -e # Salir si algo falla

# Definición de colores para la salida
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Iniciando instalación de entorno SRE 2026...${NC}"

# 1. Validar que se use Bash
if [ -z "$BASH_VERSION" ]; then
    echo -e "${RED}❌ Error: Este script requiere bash. Usa: bash install.sh${NC}"
    exit 1
fi

# 2. Detección de Sistema Operativo
OS_TYPE="$(uname)"

if [ "$OS_TYPE" = "Darwin" ]; then
    echo -e "${BLUE}🍎 Detectado macOS. Verificando Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    PACKAGE_MANAGER="brew install"
else
    echo -e "${BLUE}🐧 Detectado Linux. Actualizando APT...${NC}"
    sudo apt update
    PACKAGE_MANAGER="sudo apt install -y"
fi

# 3. Lista de herramientas esenciales (usamos nombres base)
TOOLS=(zsh starship zoxide eza bat fzf fd git curl)

echo -e "${BLUE}📦 Instalando herramientas...${NC}"
for tool in "${TOOLS[@]}"; do
    install_name=$tool
    check_name=$tool

    # Ajustes específicos para Linux (Ubuntu/Debian)
    if [ "$OS_TYPE" = "Linux" ]; then
        if [ "$tool" = "bat" ]; then
            install_name="batcat"; check_name="batcat"
        elif [ "$tool" = "fd" ]; then
            install_name="fd-find"; check_name="fdfind"
        fi
    fi
    
    # En macOS 'fd' y 'bat' se llaman igual que el paquete
    
    if ! command -v "$check_name" &> /dev/null; then
        echo -e "Instalando $install_name..."
        $PACKAGE_MANAGER "$install_name" || echo -e "${RED}⚠️ No se pudo instalar $install_name${NC}"
    else
        echo -e "${GREEN}✔ $check_name ya está instalado.${NC}"
    fi
done

# 4. Configuración de Enlaces Simbólicos (Symlinks)
echo -e "${BLUE}🔗 Enlazando configuraciones...${NC}"

# Reparar .zshrc
if [ -L "$HOME/.zshrc" ] || [ -f "$HOME/.zshrc" ]; then
    rm -f "$HOME/.zshrc"
fi

ln -sf "$HOME/dotfiles/.zshrc" "$HOME/.zshrc"
echo -e "${GREEN}✔ ~/.zshrc -> ~/dotfiles/.zshrc${NC}"

# Configuración de Starship
mkdir -p "$HOME/.config"
if [ -f "$HOME/dotfiles/starship.toml" ]; then
    ln -sf "$HOME/dotfiles/starship.toml" "$HOME/.config/starship.toml"
fi

# 5. Instalación de FZF desde fuente (Evita errores de versión)
if [ ! -d "$HOME/.fzf" ]; then
    echo -e "${BLUE}📥 Clonando FZF...${NC}"
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all --no-bash --no-fish
else
    echo -e "${GREEN}✔ FZF ya está en ~/.fzf. Actualizando...${NC}"
    (cd "$HOME/.fzf" && ./install --all --no-bash --no-fish > /dev/null)
fi

echo -e "${GREEN}✨ ¡Instalación completada!${NC}"
echo -e "${BLUE}Ejecuta: source ~/.zshrc${NC}"
