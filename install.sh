#!/bin/bash

# Colores para la terminal
set -e # Salir si algo falla
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Iniciando instalación de entorno SRE 2026...${NC}"

# 1. Detectar Sistema Operativo
OS_TYPE="$(uname)"

if [ "$OS_TYPE" == "Darwin" ]; then
    echo -e "${BLUE}🍎 Detectado macOS. Usando Homebrew...${NC}"
    if ! command -v brew &> /dev/null; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    PACKAGE_MANAGER="brew install"
elif [ -f /etc/debian_version ]; then
    echo -e "${BLUE}🐧 Detectado Debian/Ubuntu. Usando APT...${NC}"
    sudo apt update
    PACKAGE_MANAGER="sudo apt install -y"
fi

# 2. Lista de herramientas esenciales
TOOLS=(zsh starship zoxide eza bat fzf fd-find git curl)

echo -e "${BLUE}📦 Instalando herramientas: ${TOOLS[*]}...${NC}"
for tool in "${TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null && ! command -v "${tool/cat/}" &> /dev/null; then
        $PACKAGE_MANAGER "$tool"
    else
        echo -e "${GREEN}✔ $tool ya está instalado.${NC}"
    fi
done

# 3. Crear Enlaces Simbólicos (Symlinks)
echo -e "${BLUE}🔗 Enlazando archivos de configuración...${NC}"
mkdir -p ~/.config/starship
ln -sf ~/dotfiles/.zshrc ~/.zshrc
ln -sf ~/dotfiles/config/starship/starship.toml ~/.config/starship.toml
ln -sf ~/dotfiles/.gitconfig ~/.gitconfig

# 4. Configuración especial para FZF (solo si no existe)
if [ ! -d ~/.fzf ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
fi

echo -e "${GREEN}✨ ¡Entorno configurado con éxito! Reinicia tu terminal.${NC}"
