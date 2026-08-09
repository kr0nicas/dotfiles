#!/usr/bin/env bash
# Fase: fnm/Node, fzf, starship y uv. zoxide vive en lib/binaries.sh.
# Cargado por install.sh. No ejecutar suelto.

phase_runtimes() {
    # ------------------------------------------------------------------------------
    # 4. FNM + NODE.JS LTS
    # ------------------------------------------------------------------------------
    section "fnm v$FNM_VERSION + Node.js LTS"

    if ! command -v fnm >/dev/null 2>&1; then
        log "Instalando fnm v$FNM_VERSION..."
        if [[ $DRY_RUN -eq 0 ]]; then
            curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir "$LOCAL_BIN" --skip-shell
            export PATH="$LOCAL_BIN:$PATH"
            eval "$(fnm env --shell bash)"
            fnm install --lts && fnm use lts-latest
            ok "fnm + Node.js LTS instalados"
        else
            warn "DRY-RUN: fnm install omitido"
        fi
    else
        ok "fnm ya instalado ($(fnm --version))"
        if [[ $DRY_RUN -eq 0 ]]; then
            fnm install --lts 2>/dev/null || true
        fi
    fi

    # ------------------------------------------------------------------------------
    # 5. FZF v$FZF_VERSION
    # ------------------------------------------------------------------------------
    section "fzf v$FZF_VERSION"

    CURRENT_FZF="$(fzf --version 2>/dev/null | awk '{print $1}' || echo '')"

    if [[ "$CURRENT_FZF" != "$FZF_VERSION" ]]; then
        log "Instalando fzf v$FZF_VERSION (actual: ${CURRENT_FZF:-ninguna})..."
        FZF_URL="https://github.com/junegunn/fzf/releases/download/v${FZF_VERSION}/fzf-${FZF_VERSION}-${OS_TYPE}_${ARCH}.tar.gz"
        if [[ $DRY_RUN -eq 0 ]]; then
            curl -fsSL "$FZF_URL" | tar -xz -C "$LOCAL_BIN"
            ok "fzf v$FZF_VERSION instalado en $LOCAL_BIN"
        else
            warn "DRY-RUN: fzf install omitido ($FZF_URL)"
        fi
    else
        ok "fzf ya está en v$FZF_VERSION"
    fi

    # ------------------------------------------------------------------------------
    # 6. STARSHIP, UV (si no vienen del Brewfile/apt)
    # ------------------------------------------------------------------------------
    # zoxide salió de aquí: su instalador oficial consulta api.github.com sin
    # autenticar, y el límite anónimo de 60 req/h por IP tumbaba la instalación
    # en runners compartidos. Ahora lo baja phase_binaries con gh_latest_tar, que
    # sí usa GH_TOKEN cuando está. Se comprobó uno a uno que los tres de abajo no
    # tienen ese problema: solo el de zoxide llamaba a la API.
    section "Starship · uv"

    install_if_missing() {
        local cmd=$1 install_cmd=$2
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "Instalando $cmd..."
            if [[ $DRY_RUN -eq 0 ]]; then
                eval "$install_cmd" || warn "$cmd no pudo instalarse, continúa manualmente."
            else
                warn "DRY-RUN: $cmd install omitido"
            fi
        else
            ok "$cmd ya instalado ($(command -v $cmd))"
        fi
    }

    install_if_missing "starship" "curl -sS https://starship.rs/install.sh | sh -s -- --yes"
    install_if_missing "uv"       "curl -LsSf https://astral.sh/uv/install.sh | sh"

}
