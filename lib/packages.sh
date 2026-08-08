#!/usr/bin/env bash
# Fase: paquetes base (brew bundle en macOS, apt en Debian/Ubuntu).
# Cargado por install.sh. No ejecutar suelto.

phase_packages() {
    # ------------------------------------------------------------------------------
    # 3. INSTALACIÓN DE HERRAMIENTAS BASE
    # ------------------------------------------------------------------------------
    section "Herramientas Base"

    if [[ $IS_MAC -eq 1 ]]; then
        # Verificar licencia Xcode (solo si Xcode.app está instalado; con solo CLT no aplica)
        XCODE_PATH=$(xcode-select -p 2>/dev/null || echo "")
        if [[ "$XCODE_PATH" == *"Xcode.app"* ]]; then
            if ! xcodebuild -license check &>/dev/null; then
                err "Licencia de Xcode no aceptada. Ejecuta: sudo xcodebuild -license accept"
            fi
        fi

        if command -v brew >/dev/null 2>&1; then
            # Helper local para bundle modular
            run_bundle() {
                local label=$1 file=$2 flag=$3
                if [[ $flag -eq 0 ]]; then
                    warn "Skipping Brewfile${label:+.$label} (flag desactivado)"
                    return
                fi
                if [[ ! -f "$file" ]]; then
                    warn "No se encontró $file — omitiendo"
                    return
                fi
                log "Brew bundle ${label:-base}..."
                [[ $DRY_RUN -eq 0 ]] && brew bundle --file="$file" || warn "DRY-RUN: brew bundle ${label:-base} omitido"
            }
            run_bundle "" "$DOTFILES_DIR/Brewfile"        1
            run_bundle "cloud" "$DOTFILES_DIR/Brewfile.cloud" $INSTALL_CLOUD
            run_bundle "k8s" "$DOTFILES_DIR/Brewfile.k8s"   $INSTALL_K8S
            run_bundle "gui" "$DOTFILES_DIR/Brewfile.gui"   $INSTALL_GUI
        else
            err "Homebrew no encontrado. Instálalo desde https://brew.sh"
        fi
    else
        log "Actualizando apt e instalando paquetes base..."
        if [[ $DRY_RUN -eq 0 ]]; then
            sudo apt update -qq
            sudo apt install -y zsh tmux git curl jq yq ripgrep fd-find direnv age btop zstd \
                zsh-autosuggestions zsh-syntax-highlighting bsdextrautils 2>/dev/null || true

            # gh (GitHub CLI) — necesita su propio repo
            if ! command -v gh >/dev/null 2>&1; then
                log "Agregando repo GitHub CLI..."
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
                    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
                    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
                sudo apt update -qq && sudo apt install -y gh 2>/dev/null || warn "gh no pudo instalarse"
            fi

            # Neovim — el de apt suele ser muy viejo, usamos appimage como fallback
            NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${ARCH_TYPE}.appimage"
            if ! command -v nvim >/dev/null 2>&1; then
                log "Instalando Neovim via appimage..."
                if ! curl -fsI "$NVIM_URL" >/dev/null 2>&1; then
                    warn "Neovim appimage no disponible para arch=$ARCH_TYPE ($NVIM_URL). Instala manualmente o usa el paquete del SO."
                else
                    curl -fsSL -o "$LOCAL_BIN/nvim" "$NVIM_URL"
                    chmod +x "$LOCAL_BIN/nvim"
                    # Si appimage no funciona (FUSE no disponible), extraer
                    if ! "$LOCAL_BIN/nvim" --version >/dev/null 2>&1; then
                        log "AppImage sin FUSE, extrayendo..."
                        # Subshell: --appimage-extract escribe en el cwd, y así el
                        # directorio nunca se filtra a las fases siguientes.
                        ( cd /tmp && "$LOCAL_BIN/nvim" --appimage-extract >/dev/null 2>&1 )
                        rm -f "$LOCAL_BIN/nvim"
                        mv /tmp/squashfs-root "$HOME/.local/nvim-squashfs"
                        ln -sf "$HOME/.local/nvim-squashfs/usr/bin/nvim" "$LOCAL_BIN/nvim"
                    fi
                    ok "Neovim instalado: $($LOCAL_BIN/nvim --version | head -1)"
                fi
            else
                NVIM_VER=$(nvim --version | head -1 | grep -oP '\d+\.\d+')
                if (( $(echo "$NVIM_VER < 0.10" | bc -l) )); then
                    warn "Neovim $NVIM_VER es muy viejo (se necesita >=0.10). Actualizando..."
                    if ! curl -fsI "$NVIM_URL" >/dev/null 2>&1; then
                        warn "Neovim appimage no disponible para arch=$ARCH_TYPE — actualiza manualmente."
                    else
                        curl -fsSL -o "$LOCAL_BIN/nvim" "$NVIM_URL"
                        chmod +x "$LOCAL_BIN/nvim"
                        if ! "$LOCAL_BIN/nvim" --version >/dev/null 2>&1; then
                            # Subshell: el cwd nunca se filtra a las fases siguientes.
                            ( cd /tmp && "$LOCAL_BIN/nvim" --appimage-extract >/dev/null 2>&1 )
                            rm -f "$LOCAL_BIN/nvim"
                            mv /tmp/squashfs-root "$HOME/.local/nvim-squashfs"
                            ln -sf "$HOME/.local/nvim-squashfs/usr/bin/nvim" "$LOCAL_BIN/nvim"
                        fi
                        ok "Neovim actualizado: $($LOCAL_BIN/nvim --version | head -1)"
                    fi
                fi
            fi

            # fd → symlink fdfind si hace falta
            if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
                ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
                ok "Symlink fd → fdfind creado"
            fi

            # eza (no está en apt por defecto)
            if ! command -v eza >/dev/null 2>&1; then
                log "Instalando eza..."
                sudo mkdir -p /etc/apt/keyrings
                wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main" \
                    | sudo tee /etc/apt/sources.list.d/gierens.list
                sudo apt update -qq && sudo apt install -y eza 2>/dev/null || warn "eza no pudo instalarse"
            fi

            # bat → symlink batcat si hace falta
            if ! command -v bat >/dev/null 2>&1; then
                sudo apt install -y bat 2>/dev/null || true
                if command -v batcat >/dev/null 2>&1 && [[ ! -f "$LOCAL_BIN/bat" ]]; then
                    ln -sf /usr/bin/batcat "$LOCAL_BIN/bat"
                    ok "Symlink bat → batcat creado"
                fi
            fi
        else
            warn "DRY-RUN: apt install omitido"
        fi
    fi

}
