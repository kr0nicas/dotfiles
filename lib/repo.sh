#!/usr/bin/env bash
# Fase: configuración del repo (hooks de git).
# Cargado por install.sh. No ejecutar suelto.

phase_repo() {
    # ------------------------------------------------------------------------------
    # 9b. HOOKS DE GIT
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

    if ! git -C "$DOTFILES_DIR" config core.hooksPath .githooks 2>/dev/null; then
        warn "No se pudo configurar core.hooksPath (¿no es un repo git?)"
        return
    fi

    # Se comprueba hook por hook en vez de un chmod con `|| true`. Con el
    # `|| true`, un .githooks/ incompleto se anunciaba igual como "Hooks
    # activos": un barrido de secretos ausente se reportaba como presente,
    # que es exactamente la mentira que este arnés existe para evitar.
    local faltan=0 h ruta
    for h in commit-msg pre-commit pre-push; do
        ruta="$DOTFILES_DIR/.githooks/$h"
        if [[ ! -f "$ruta" ]]; then
            warn "Hook ausente: .githooks/$h"
            faltan=1
        elif [[ ! -x "$ruta" ]] && ! chmod +x "$ruta"; then
            warn "No se pudo hacer ejecutable: .githooks/$h"
            faltan=1
        fi
    done

    if [[ $faltan -eq 0 ]]; then
        ok "Hooks activos: commit-msg, pre-commit, pre-push"
    else
        warn "core.hooksPath configurado, pero faltan hooks — revisa los avisos"
    fi
}
