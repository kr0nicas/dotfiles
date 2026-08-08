#!/usr/bin/env bash
# Fase: tmux/TPM, Neovim/lazy.nvim y Claude Code.
# Cargado por install.sh. No ejecutar suelto.

phase_editors() {
    # ------------------------------------------------------------------------------
    # 7. TMUX — TPM Y PLUGINS
    # ------------------------------------------------------------------------------
    section "Tmux Plugin Manager (TPM)"

    TPM_DIR="$HOME/.tmux/plugins/tpm"

    if [[ ! -d "$TPM_DIR" ]]; then
        log "Instalando TPM..."
        if [[ $DRY_RUN -eq 0 ]]; then
            git clone https://github.com/tmux-plugins/tpm "$TPM_DIR" --depth=1
            ok "TPM instalado en $TPM_DIR"
        else
            warn "DRY-RUN: TPM install omitido"
        fi
    else
        ok "TPM ya instalado en $TPM_DIR"
        if [[ $DRY_RUN -eq 0 ]]; then
            git -C "$TPM_DIR" pull --rebase --quiet && ok "TPM actualizado" || warn "TPM update falló, continúa..."
        fi
    fi

    # ------------------------------------------------------------------------------
    # 8. NEOVIM — LAZY.NVIM (bootstrap automático al abrir nvim)
    # ------------------------------------------------------------------------------
    section "Neovim"

    if command -v nvim >/dev/null 2>&1; then
        ok "Neovim encontrado: $(nvim --version | head -1)"
    else
        warn "Neovim no encontrado — instálalo manualmente si brew/apt falló"
    fi

    # ------------------------------------------------------------------------------
    # 8b. CLAUDE CODE — build nativo (independiente de fnm/npm)
    # ------------------------------------------------------------------------------
    # Evita perder `claude` del PATH cuando fnm cambia de versión de node al entrar
    # a un proyecto con .nvmrc/.node-version. El build nativo vive en ~/.local/bin
    # y no depende de la versión activa de node.
    section "Claude Code (native build)"

    if [[ -d "$HOME/.local/share/claude" ]]; then
        ok "Claude Code nativo ya activo ($HOME/.local/bin/claude)"
    elif command -v claude >/dev/null 2>&1; then
        log "Detectado claude vía npm/fnm — migrando a build nativo..."
        if [[ $DRY_RUN -eq 0 ]]; then
            if claude install stable --force >/dev/null 2>&1; then
                ok "Migrado a build nativo en ~/.local/bin/claude"
            else
                warn "Migración falló — corre manualmente: claude install stable --force"
            fi
        else
            warn "DRY-RUN: claude install stable --force omitido"
        fi
    else
        if [[ $DRY_RUN -eq 0 ]]; then
            log "Instalando Claude Code nativo..."
            if curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1; then
                ok "Claude Code instalado en ~/.local/bin/claude"
            else
                warn "Instalación falló — manual: curl -fsSL https://claude.ai/install.sh | bash"
            fi
        else
            warn "DRY-RUN: instalación de claude omitida"
        fi
    fi

}
