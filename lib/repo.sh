#!/usr/bin/env bash
# Fase: configuración del repo (hooks de git).
# Cargado por install.sh. No ejecutar suelto.

phase_repo() {
    # ------------------------------------------------------------------------------
    # 10. HOOKS DE GIT
    # ------------------------------------------------------------------------------
    section "Configurando hooks del repo"

    if [[ ! -d "$DOTFILES_DIR/.githooks" ]]; then
        warn "No hay .githooks/, omitiendo"
        return
    fi

    # core.hooksPath es config local del clon: no viaja en el repo. Sin esta
    # fase los hooks existen pero no se ejecutan en ninguna máquina nueva.
    if [[ $DRY_RUN -eq 1 ]]; then
        warn "DRY-RUN: git config core.hooksPath .githooks"
        return
    fi

    if git -C "$DOTFILES_DIR" config core.hooksPath .githooks 2>/dev/null; then
        chmod +x "$DOTFILES_DIR"/.githooks/commit-msg \
                 "$DOTFILES_DIR"/.githooks/pre-commit \
                 "$DOTFILES_DIR"/.githooks/pre-push 2>/dev/null || true
        ok "Hooks activos: commit-msg, pre-commit, pre-push"
    else
        warn "No se pudo configurar core.hooksPath (¿no es un repo git?)"
    fi
}
