#!/usr/bin/env bash
# Fase: symlinks de dotfiles.
# Cargado por install.sh. No ejecutar suelto.
#
# El archivo está partido en un grupo por destino (symlinks_*), y no en un
# phase_symlinks monolítico como antes, porque no todos los consumidores del
# repo quieren todos los symlinks: el preset --agent solo necesita el bloque de
# ~/.claude/ —una caja de agente nunca renderiza un prompt, un tmux ni un
# nvim—, y pedirlo sin partir la fase obligaba a duplicar ese bloque.
#
# Las dos entradas (phase_symlinks y phase_symlinks_agent) no hacen más que
# elegir qué grupos llamar. Si añades un grupo, añádelo a phase_symlinks: el
# test lib/symlinks.test.sh comprueba que su salida es exactamente la
# concatenación de los grupos, así que un grupo huérfano falla ahí.

# safe_link y safe_mkdir viven a nivel de archivo, y no dentro de una fase como
# estaban, porque ahora las comparten todos los grupos.
safe_link() {
    local src=$1 dest=$2
    if [[ ! -f "$src" ]]; then
        warn "Fuente no encontrada, omitiendo: $src"
        return
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        warn "DRY-RUN: ln -sf $src → $dest"
        return
    fi
    # Si el destino ya existe y NO es symlink al mismo src, respaldar antes de pisar
    if [[ -e "$dest" || -L "$dest" ]]; then
        if [[ -L "$dest" ]] && [[ "$(readlink "$dest")" == "$src" ]]; then
            : # ya apunta al repo, nada que hacer
        elif [[ -L "$dest" ]]; then
            rm -f "$dest"
        else
            local backup
            backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
            mv "$dest" "$backup"
            warn "Config existente respaldada: $backup"
        fi
    fi
    ln -sf "$src" "$dest"
    ok "Linked: $dest → $src"
}

safe_mkdir() {
    local dir=$1
    if [[ $DRY_RUN -eq 1 ]]; then
        [[ -d "$dir" ]] || warn "DRY-RUN: mkdir -p $dir"
        return
    fi
    mkdir -p "$dir"
}

# --- Grupos ---------------------------------------------------------------------

# Shell, multiplexor, git y prompt: todo lo que solo existe para una sesión
# interactiva de una persona.
symlinks_shell() {
    safe_link "$DOTFILES_DIR/zshrc"                         "$HOME/.zshrc"
    safe_link "$DOTFILES_DIR/tmux.conf"                     "$HOME/.tmux.conf"
    safe_link "$DOTFILES_DIR/.gitconfig"                    "$HOME/.gitconfig"
    safe_link "$DOTFILES_DIR/config/starship/starship.toml" "$HOME/.config/starship.toml"
    # Fallback para cajas sin nvim (ver VIM_GUIA.md). Antes vivía en el repo sin
    # llegar nunca a la máquina, así que el "fallback" no existía en la práctica.
    safe_link "$DOTFILES_DIR/vimrc"                         "$HOME/.vimrc"
}

# SSH color map (override local posible: ~/.ssh/colors.conf, sin symlink)
symlinks_ssh() {
    if [[ -f "$DOTFILES_DIR/config/ssh/colors.conf" ]]; then
        safe_mkdir "$HOME/.ssh"
        [[ $DRY_RUN -eq 0 ]] && chmod 700 "$HOME/.ssh"
        safe_link "$DOTFILES_DIR/config/ssh/colors.conf" "$HOME/.ssh/colors.conf"
    fi
}

# Claude Code settings + statusline + CLAUDE.md global.
# Es el único grupo que pide el preset --agent.
symlinks_claude() {
    if [[ -f "$DOTFILES_DIR/config/claude/settings.json" ]]; then
        safe_mkdir "$HOME/.claude"
        safe_link "$DOTFILES_DIR/config/claude/settings.json" "$HOME/.claude/settings.json"
        safe_link "$DOTFILES_DIR/config/claude/statusline.sh"  "$HOME/.claude/statusline.sh"
        safe_link "$DOTFILES_DIR/config/claude/CLAUDE.md"      "$HOME/.claude/CLAUDE.md"

        # settings.local.json: overrides por máquina (no versionado). Sembrar desde example si falta.
        if [[ ! -e "$HOME/.claude/settings.local.json" ]]; then
            if [[ $DRY_RUN -eq 0 ]]; then
                cp "$DOTFILES_DIR/config/claude/settings.local.json.example" "$HOME/.claude/settings.local.json"
                ok "Sembrado: ~/.claude/settings.local.json (edítalo para overrides locales)"
            else
                warn "DRY-RUN: sembraría ~/.claude/settings.local.json"
            fi
        fi
    fi
}

# rtk (Rust Token Killer) config — ruta de config difiere por OS.
# El hook de Claude Code va declarado y guardado en config/claude/settings.json,
# así que no hay que correr `rtk init` en ninguna máquina.
symlinks_rtk() {
    if [[ -f "$DOTFILES_DIR/config/rtk/config.toml" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            RTK_CFG_DIR="$HOME/Library/Application Support/rtk"
        else
            RTK_CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rtk"
        fi
        safe_mkdir "$RTK_CFG_DIR"
        safe_link "$DOTFILES_DIR/config/rtk/config.toml" "$RTK_CFG_DIR/config.toml"
    fi
}

# WezTerm config
symlinks_wezterm() {
    if [[ -f "$DOTFILES_DIR/config/wezterm/wezterm.lua" ]]; then
        if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
            # WSL2: el symlink debe vivir en el lado Windows (~/.config/wezterm/)
            # WezTerm corre como app Windows y no ve el filesystem de WSL directamente
            WIN_HOME=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r\n')
            WIN_CONFIG="$WIN_HOME\\.config\\wezterm"
            WIN_SRC=$(wslpath -w "$DOTFILES_DIR/config/wezterm/wezterm.lua")
            WIN_DEST="$WIN_CONFIG\\wezterm.lua"

            if [[ -n "$WIN_HOME" ]] && [[ $DRY_RUN -eq 0 ]]; then
                powershell.exe -NoProfile -Command "
                    \$dest = '$WIN_DEST'
                    \$src  = '$WIN_SRC'
                    New-Item -ItemType Directory -Force -Path (Split-Path \$dest) | Out-Null
                    if (Test-Path \$dest) { Remove-Item \$dest -Force }
                    New-Item -ItemType SymbolicLink -Path \$dest -Target \$src | Out-Null
                    Write-Host 'Linked (Windows): ' + \$dest
                " 2>/dev/null \
                && ok "Linked (Windows): $WIN_DEST → $WIN_SRC" \
                || warn "Symlink Windows requiere Modo Desarrollador o PowerShell como Admin — copia manual: cp $DOTFILES_DIR/config/wezterm/wezterm.lua $(wslpath "$WIN_HOME")/.config/wezterm/wezterm.lua"
            elif [[ $DRY_RUN -eq 1 ]]; then
                warn "DRY-RUN: New-Item SymbolicLink $WIN_DEST → $WIN_SRC"
            fi
        else
            # macOS / Linux nativo
            safe_mkdir "$HOME/.config/wezterm"
            safe_link "$DOTFILES_DIR/config/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
        fi
    fi
}

# iTerm2 Dynamic Profile (solo macOS). iTerm lee todo lo que haya en
# DynamicProfiles/ y lo recarga en caliente, así que el symlink basta.
# El perfil NO se vuelve el predeterminado solo: hay que elegirlo una vez en
# Settings → Profiles → SRE 2026 → Other Actions → Set as Default.
symlinks_iterm2() {
    if [[ "$OSTYPE" == "darwin"* ]] && [[ -f "$DOTFILES_DIR/config/iterm2/dotfiles.json" ]]; then
        ITERM_PROFILE_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
        safe_mkdir "$ITERM_PROFILE_DIR"
        safe_link "$DOTFILES_DIR/config/iterm2/dotfiles.json" "$ITERM_PROFILE_DIR/dotfiles.json"
    fi
}

# direnv config directory
symlinks_direnv() {
    if [[ -d "$DOTFILES_DIR/config/direnv" ]]; then
        safe_mkdir "$HOME/.config/direnv"
        safe_link "$DOTFILES_DIR/config/direnv/direnv.toml" "$HOME/.config/direnv/direnv.toml"
    fi
}

# Neovim: el directorio de config entero (no un archivo, así que no pasa por
# safe_link) más el bootstrap de lazy.nvim.
symlinks_nvim() {
    if [[ -d "$DOTFILES_DIR/config/nvim" ]]; then
        if [[ $DRY_RUN -eq 0 ]]; then
            # Si ya existe un dir real (no symlink al repo), respaldar antes de pisar
            if [[ -e "$HOME/.config/nvim" && ! -L "$HOME/.config/nvim" ]]; then
                BACKUP="$HOME/.config/nvim.bak.$(date +%Y%m%d-%H%M%S)"
                mv "$HOME/.config/nvim" "$BACKUP"
                warn "Config existente respaldada en: $BACKUP"
            elif [[ -L "$HOME/.config/nvim" ]]; then
                rm -f "$HOME/.config/nvim"
            fi
            ln -sf "$DOTFILES_DIR/config/nvim" "$HOME/.config/nvim"
            ok "Linked: ~/.config/nvim → $DOTFILES_DIR/config/nvim"
        else
            warn "DRY-RUN: ln -sf $DOTFILES_DIR/config/nvim → ~/.config/nvim (con backup automático si aplica)"
        fi
    fi

    # Instalar plugins de Neovim headless (lazy.nvim bootstrap)
    if command -v nvim >/dev/null 2>&1 && [[ -d "$HOME/.config/nvim" && $DRY_RUN -eq 0 ]]; then
        log "Instalando plugins Neovim (lazy.nvim sync)..."
        nvim --headless -c 'lua require("lazy").sync({ wait = true })' -c 'qa' 2>/dev/null \
            && ok "Plugins Neovim instalados" \
            || warn "Plugins no instalados headless — abre nvim y lazy.nvim los descargará"
    fi
}

# --- Fases ----------------------------------------------------------------------

phase_symlinks() {
    # ------------------------------------------------------------------------------
    # 9. SYMLINKS DE DOTFILES
    # ------------------------------------------------------------------------------
    section "Sincronizando Symlinks"

    safe_mkdir "$HOME/.config"

    symlinks_shell
    symlinks_ssh
    symlinks_claude
    symlinks_rtk
    symlinks_wezterm
    symlinks_iterm2
    symlinks_direnv
    symlinks_nvim
}

# Variante del preset --agent: solo ~/.claude/.
#
# Todo lo demás que enlaza phase_symlinks lo lee algo que un agente no ejecuta
# nunca. La tool Bash de Claude Code es una zsh NO interactiva que no sourcea
# zshrc, así que ni el zshrc ni sus aliases ni el prompt de starship ni los
# keybindings de fzf llegan a renderizarse; tmux, nvim, wezterm y el perfil de
# iTerm2 necesitan una terminal delante. Enlazarlos en una caja de agente no
# rompe nada, pero tampoco lo lee nadie.
#
# ~/.config no se crea aquí: los tres destinos cuelgan de ~/.claude.
phase_symlinks_agent() {
    section "Sincronizando Symlinks (solo ~/.claude)"

    symlinks_claude
}
