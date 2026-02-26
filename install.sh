#!/bin/bash

# Colores para mensajes limpios
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Configurando tus dotfiles de 2026...${NC}"

# 1. Crear directorios necesarios
mkdir -p ~/.config/starship

# 2. Crear enlaces simbólicos (ln -sf: s de simbólico, f de forzar si ya existe)
echo -e "Enlazando .zshrc..."
ln -sf ~/dotfiles/.zshrc ~/.zshrc

echo -e "Enlazando configuración de Starship..."
ln -sf ~/dotfiles/config/starship/starship.toml ~/.config/starship.toml

echo "Enlazando .gitconfig..."
ln -sf ~/dotfiles/.gitconfig ~/.gitconfig


# 3. Asegurar que Zsh sea el shell por defecto
if [ "$SHELL" != "$(which zsh)" ]; then
    echo -e "${BLUE}Cambiando shell por defecto a Zsh...${NC}"
    sudo chsh -s $(which zsh) $USER
fi

echo -e "${GREEN}¡Todo listo! Reinicia tu terminal o escribe 'source ~/.zshrc'${NC}"
