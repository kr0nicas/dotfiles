#!/usr/bin/env bash
# Fase: limpieza de cache zsh y resumen final.
# Cargado por install.sh. No ejecutar suelto.

# Herramientas que el resumen final comprueba, una por línea, según lo que
# esta instalación debía traer.
#
# Antes era una lista fija, y con --vps, --container o --no-k8s el resumen
# salía con ❌ en kubectl, helm o tofu por diseño; docker, que en Linux no se
# instala a propósito, era ❌ en todo Linux, y jless en todo ARM. Un ❌ que sale
# siempre entrena a ignorar el resumen entero, que es justo lo que CLAUDE.md
# pide evitar. Vive a nivel de archivo para que lib/verify.test.sh la pruebe
# sin instalar nada.
verify_tools() {
    printf '%s\n' zsh git curl fzf node npm uv ruff starship zoxide eza bat gh tmux nvim \
        rg fd lazygit direnv delta trivy dust btop curlie jq yq zstd
    # jless solo publica build de x86_64 para Linux.
    if [[ ${IS_MAC:-0} -eq 1 || "${ARCH_TYPE:-}" == "x86_64" ]]; then
        echo jless
    fi
    if [[ ${INSTALL_K8S:-0} -eq 1 ]]; then
        printf '%s\n' k9s kubectl helm stern kubectx
        # En macOS docker es el cliente del Brewfile.k8s; en Linux el daemon
        # lo pone el aprovisionamiento, no estos dotfiles.
        [[ ${IS_MAC:-0} -eq 1 ]] && echo docker
    fi
    if [[ ${INSTALL_CLOUD:-0} -eq 1 ]]; then
        echo tofu
    fi
    return 0
}

phase_verify() {
    # ------------------------------------------------------------------------------
    # 10. LIMPIEZA DE CACHÉ ZSH
    # ------------------------------------------------------------------------------
    section "Limpieza"

    if [[ $DRY_RUN -eq 0 ]]; then
        rm -f "$HOME"/.zcompdump* 2>/dev/null || true
        ok "Caché zsh limpiado"
    else
        warn "DRY-RUN: limpieza omitida"
    fi

    # ------------------------------------------------------------------------------
    # 11. RESUMEN FINAL
    # ------------------------------------------------------------------------------
    section "Resumen de instalación"

    echo ""
    printf "  %-14s %-30s %s\n" "HERRAMIENTA" "RUTA" "ESTADO"
    printf "  %-14s %-30s %s\n" "──────────" "────────────────────────────" "──────"
    for t in $(verify_tools); do
        path_t=$(command -v "$t" 2>/dev/null || echo "—")
        status=$([[ "$path_t" != "—" ]] && echo "✅" || echo "❌")
        printf "  %-14s %-30s %s\n" "$t" "$path_t" "$status"
    done

    # Estado TPM y lazy.nvim. Con --agent no corre phase_editors, así que estas
    # dos filas serían un ❌ permanente por diseño — y un ❌ que sale siempre
    # entrena a ignorar el resumen entero, que es peor que no tener resumen.
    if [[ $INSTALL_AGENT -eq 0 ]]; then
        tpm_status=$([[ -d "$HOME/.tmux/plugins/tpm" ]] && echo "✅" || echo "❌")
        lazy_status=$([[ -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ]] && echo "✅" || echo "❌")
        printf "  %-14s %-30s %s\n" "tpm"       "$HOME/.tmux/plugins/tpm"                "$tpm_status"
        printf "  %-14s %-30s %s\n" "lazy.nvim" "$HOME/.local/share/nvim/lazy/lazy.nvim"  "$lazy_status"
    fi
    echo ""

    ok "¡Entorno SRE 2026 listo!"
    if [[ $INSTALL_AGENT -eq 1 ]]; then
        # Aquí no hay ~/.zshrc que sourcear: el preset no lo enlaza a propósito.
        # Lo que de verdad hace falta es que ~/.local/bin esté en el PATH del
        # proceso del agente, porque su tool Bash no sourcea zshrc y ahí es
        # donde instalan phase_runtimes y phase_binaries.
        warn "Caja de agente: asegúrate de que $LOCAL_BIN está en el PATH del agente (su Bash no sourcea zshrc)."
    else
        warn "Ejecuta: source ~/.zshrc"
    fi
}
