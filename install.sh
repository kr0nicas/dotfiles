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
# NOTA DE SEGURIDAD — postura de integridad:
#
# VERIFICADO. Los binarios de GitHub Releases (sección 6b) se descargan a disco
# y se comparan contra el checksums.txt del propio release antes de instalarse.
# Un checksum que NO coincide aborta el instalador entero: es la única señal que
# distingue una descarga corrupta de una manipulada, y no se traga en silencio.
#
# NO VERIFICABLE. Algunos proyectos no publican checksums en sus releases
# (delta y dust, hoy). Esos se instalan igual, pero con un warning visible por
# herramienta — el hueco queda auditable en la salida, no escondido.
#
# RIESGO ACEPTADO. Los `curl … | bash` de upstream installers oficiales (fnm,
# starship, zoxide, uv, trivy, helm, claude) siguen sin verificación: son
# scripts vivos, sin versión ni checksum publicado, y es la vía documentada por
# cada proyecto. Si te preocupa supply chain:
#   1. Revisa cada URL antes de ejecutar (todos son HTTPS, hosts oficiales).
#   2. Usa --dry-run para auditar qué se descarga.
#   3. Sustituye ese bloque por una descarga pineada a versión + sha256.
# ==============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# ORQUESTACIÓN
# ------------------------------------------------------------------------------
# Este archivo solo decide QUÉ se hace y en qué orden. El CÓMO vive en lib/,
# una fase por archivo. Para añadir una herramienta, toca el lib/ que le
# corresponde, no este archivo.

# La raíz del repo se deriva de la ubicación de este script: antes estaba fija
# en $HOME/dotfiles, así que clonar en otra ruta rompía todos los symlinks.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DOTFILES_DIR="$SCRIPT_DIR"

# --- Variables globales -------------------------------------------------------
FNM_VERSION="1.38.1"
FZF_VERSION="0.66.0"
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

# --- Carga de fases -----------------------------------------------------------
# Explícito y no en un bucle: así `shellcheck -x` sigue cada source y analiza el
# conjunto de verdad, en vez de ver cada archivo aislado y creer que todas estas
# variables globales están sin usar.
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/menu.sh
source "$SCRIPT_DIR/lib/menu.sh"
# shellcheck source=lib/detect.sh
source "$SCRIPT_DIR/lib/detect.sh"
# shellcheck source=lib/packages.sh
source "$SCRIPT_DIR/lib/packages.sh"
# shellcheck source=lib/runtimes.sh
source "$SCRIPT_DIR/lib/runtimes.sh"
# shellcheck source=lib/binaries.sh
source "$SCRIPT_DIR/lib/binaries.sh"
# shellcheck source=lib/editors.sh
source "$SCRIPT_DIR/lib/editors.sh"
# shellcheck source=lib/symlinks.sh
source "$SCRIPT_DIR/lib/symlinks.sh"
# shellcheck source=lib/repo.sh
source "$SCRIPT_DIR/lib/repo.sh"
# shellcheck source=lib/verify.sh
source "$SCRIPT_DIR/lib/verify.sh"

# --- Flags --------------------------------------------------------------------
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

# --- Arranque: banner, update, perfil ------------------------------------------
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

# --- Fases, en orden ------------------------------------------------------------
phase_detect      # SO, arquitectura, dependencias críticas
phase_packages    # brew bundle (macOS) / apt (Debian-Ubuntu)
phase_runtimes    # fnm+Node, fzf, starship, zoxide, uv
phase_binaries    # binarios SRE desde GitHub Releases (solo Linux)
phase_editors     # tmux/TPM, Neovim/lazy.nvim, Claude Code
phase_symlinks    # symlinks de dotfiles
phase_repo        # hooks de git (core.hooksPath)
phase_verify      # limpieza de caché zsh + resumen final
