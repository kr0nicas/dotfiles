#!/usr/bin/env bash
# Fase: deteccion de SO/arquitectura y dependencias criticas.
# Cargado por install.sh. No ejecutar suelto.

phase_detect() {
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

}
