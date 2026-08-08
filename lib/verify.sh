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

    # Estado TPM y lazy.nvim
    tpm_status=$([[ -d "$HOME/.tmux/plugins/tpm" ]] && echo "✅" || echo "❌")
    lazy_status=$([[ -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ]] && echo "✅" || echo "❌")
    printf "  %-14s %-30s %s\n" "tpm"       "$HOME/.tmux/plugins/tpm"                "$tpm_status"
    printf "  %-14s %-30s %s\n" "lazy.nvim" "$HOME/.local/share/nvim/lazy/lazy.nvim"  "$lazy_status"
    echo ""

    ok "¡Entorno SRE 2026 listo!"
    warn "Ejecuta: source ~/.zshrc"
}
