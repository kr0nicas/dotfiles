#!/usr/bin/env bash
# Fase: limpieza de cache zsh y resumen final.
# Cargado por install.sh. No ejecutar suelto.

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
    for t in zsh git curl fzf node npm uv ruff starship zoxide eza bat gh tmux nvim rg fd k9s kubectl helm stern kubectx lazygit direnv delta trivy tofu docker dust btop curlie jless jq yq zstd; do
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
