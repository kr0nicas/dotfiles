#!/usr/bin/env bash
# Ayuda, menus interactivos y deteccion de instalacion previa.
# Cargado por install.sh. No ejecutar suelto.

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
  --agent          Perfil Caja de agente: el consumidor es Claude Code, no una
                   persona. Herramientas, hooks de git y ~/.claude; sin tmux ni
                   nvim, y sin las configs que solo lee una shell interactiva
  --no-cloud       Omite Cloud/IaC (aws, azure, tofu, vault, tflint, gcloud)
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
  ./install.sh --agent                  # Caja para un agente de Claude Code
  ./install.sh --agent --no-k8s         # Igual, sin kubectl/helm/k9s
  ./install.sh --minimal                # Solo shell + nvim + langs
  ./install.sh --no-cloud --no-k8s      # Workstation sin SRE tools
EOF
    exit 0
}

ask_modules() {
    local r
    read -rp "  ¿Incluir Cloud/IaC (aws, tofu, gcloud)?        [Y/n]: " r
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
    echo "  5) Caja de agente          (herramientas + hooks + ~/.claude, sin editores)"
    echo "  6) Personalizado           (te pregunto módulo por módulo)"
    echo "  q) Cancelar"
    echo
    local choice
    read -rp "Opción [1-6/q]: " choice
    echo
    case "$choice" in
        1)   INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=1; ok "Perfil: Workstation completo" ;;
        2)   INSTALL_CLOUD=1; INSTALL_K8S=0; INSTALL_GUI=0; ok "Perfil: Servidor / VPS" ;;
        3)   INSTALL_CLOUD=0; INSTALL_K8S=0; INSTALL_GUI=0; ok "Perfil: Container / Docker" ;;
        4)   INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=0; ok "Perfil: Nodo Kubernetes" ;;
        5)   INSTALL_AGENT=1; INSTALL_GUI=0;                ok "Perfil: Caja de agente" ;;
        6)   ask_modules; ok "Perfil: Personalizado" ;;
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
        # @{u} es sintaxis de git (upstream), no expansión de shell — de ahí el disable.
        # shellcheck disable=SC1083
        behind_count=$(git -C "$DOTFILES_DIR" rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
        # shellcheck disable=SC1083
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
