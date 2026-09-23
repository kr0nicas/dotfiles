#!/usr/bin/env bash
# Fase: paquetes base (brew bundle en macOS, apt en Debian/Ubuntu).
# Cargado por install.sh. No ejecutar suelto.

# ¿La versión $1 (X.Y[.Z]) es anterior a $2 (0.11 por defecto)?
#
# Compara mayor y menor como enteros. Antes lo hacía `bc` tratándolas como
# decimales, y para bc 0.9 > 0.10: un nvim 0.7–0.9 de apt nunca se actualizaba.
# bc tampoco está en la lista de apt, así que en una imagen mínima la
# comprobación ni se ejecutaba. El mínimo es 0.11 porque
# config/nvim/lua/plugins/lsp.lua usa vim.lsp.enable(), que no existe antes.
#
# A nivel de archivo, como brew_untrusted_taps, para que lib/packages.test.sh
# la pruebe sin un nvim delante.
nvim_too_old() {
    local have=$1 min=${2:-0.11} h_major h_minor m_major m_minor
    IFS=. read -r h_major h_minor _ <<<"$have"
    IFS=. read -r m_major m_minor _ <<<"$min"
    [[ "$h_major" =~ ^[0-9]+$ && "$h_minor" =~ ^[0-9]+$ ]] || return 1
    (( h_major < m_major || (h_major == m_major && h_minor < m_minor) ))
}

# Instala paquetes de apt de forma que un paquete que falta no se lleve al
# resto por delante.
#
# Instalar varios paquetes en una sola llamada a apt es todo o nada: si uno no
# existe en esa release (btop no está en bullseye ni en focal; bsdextrautils
# tampoco en focal), no instala ninguno. Con el `2>/dev/null || true` de antes eso pasaba en silencio y luego
# faltaban unzip, jq o rg sin que nada lo dijera. Primero se intenta el lote
# —lo normal es que funcione y es mucho más rápido— y solo si falla se repite
# paquete a paquete, avisando de los que no se pudieron instalar.
apt_install() {
    local missing=() p
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1 && return 0
    for p in "$@"; do
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$p" >/dev/null 2>&1 \
            || missing+=("$p")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "apt no pudo instalar: ${missing[*]} (el resto sí se instaló)"
    fi
    return 0
}

# Extrae los taps que Homebrew rechazó por no estar en su lista de confianza,
# leyendo una salida de `brew bundle` ya guardada en un archivo.
#
# Vive a nivel de archivo, y no dentro de phase_packages como el resto, para
# poder probarla contra una salida capturada sin brew delante ni nada que
# instalar: lib/packages.test.sh la ejercita así.
#
# El mensaje de Homebrew es "Refusing to load formula X from untrusted tap Y."
# y aparece igual para casks y comandos externos, así que el anclaje es "from
# untrusted tap" y no la palabra "formula". El punto final se recorta aparte
# porque cierra la frase y no forma parte del nombre del tap.
brew_untrusted_taps() {
    [[ -f "$1" ]] || return 0
    grep -o 'from untrusted tap [^ ]*' "$1" 2>/dev/null \
        | sed 's/.*tap //; s/\.$//' \
        | sort -u
}

# ¿Puede esta caja instalar paquetes del sistema sin que nadie teclee nada?
#
# `sudo -n true` y no `command -v sudo`: lo que importa no es que sudo exista,
# sino que conteste sin pedir contraseña. Una caja de agente no tiene a quién
# preguntársela, así que un sudo que prompt-ea equivale a no tener sudo — con la
# diferencia de que se cuelga esperando en vez de fallar.
#
# Vive a nivel de archivo, como brew_untrusted_taps, para poder probarla sin un
# sistema delante: `id` y `sudo` son comandos externos, así que un test los
# sombrea con funciones del mismo nombre. lib/packages.test.sh lo hace así.
packages_can_elevate() {
    [[ "$(id -u)" -eq 0 ]] && return 0
    command -v sudo >/dev/null 2>&1 || return 1
    sudo -n true 2>/dev/null
}

# phase_packages, pero sin abortar la instalación en una caja sin root.
#
# Solo la usa el preset --agent, y existe porque el bloque de Debian es todo
# `sudo apt` y su primera línea —`sudo apt update`— no lleva `|| true`: en un
# sandbox sin root muere ahí y se lleva por delante el instalador entero bajo
# `set -e`. Se degrada en vez de omitirse a secas porque de esta fase salen
# justo las herramientas que un agente usa más: rg, fd, bat, jq, yq y unzip NO
# están en lib/binaries.sh.
phase_packages_if_possible() {
    # macOS nunca se salta: aquí la fase es `brew bundle`, que no usa sudo, y es
    # además la ÚNICA fuente de binarios del repo en Mac (phase_binaries es solo
    # Linux). Y en dry-run tampoco, porque la fase ya no instala nada y saltarla
    # haría que la salida de `--dry-run --agent` dependiera de si esta máquina
    # tiene sudo — el oráculo dejaría de ser determinista.
    if [[ ${IS_MAC:-0} -eq 1 ]] || [[ $DRY_RUN -eq 1 ]] || packages_can_elevate; then
        phase_packages
        return
    fi

    section "Herramientas Base"
    warn "Sin root y sin sudo no interactivo: se omiten los paquetes del sistema."
    warn "La imagen base debe traer, además de curl/git/zsh que ya exige phase_detect:"
    warn "    jq yq ripgrep fd-find bat eza unzip zstd age direnv btop gh"
    warn "El que más duele es unzip: sin él, jless, lnav y tflint se saltan en la fase siguiente."
}

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
                # No colapsar esto en `[[ cond ]] && cmd || warn`: en esa forma el
                # `||` no distingue "no se ejecutó por dry-run" de "se ejecutó y
                # falló", así que un brew bundle roto imprimía "DRY-RUN omitido"
                # en una instalación real y devolvía 0. Es como Brewfile.cloud y
                # Brewfile.k8s llevaban tiempo sin instalarse sin que nadie lo
                # viera: brew aborta el archivo entero en la primera fórmula que
                # no resuelve, y el instalador lo daba por bueno.
                if [[ $DRY_RUN -eq 1 ]]; then
                    warn "DRY-RUN: brew bundle ${label:-base} omitido"
                    return
                fi

                # La salida se duplica con tee en vez de capturarse a secas: así
                # el progreso de brew se sigue viendo en vivo —que puede ser un
                # rato largo— y a la vez queda un archivo que inspeccionar si
                # falla. El rc sale de PIPESTATUS porque el de la tubería es el
                # de tee, que siempre es 0.
                local out rc tap
                out=$(mktemp) || { warn "No se pudo crear el temporal para la salida de brew"; return; }
                brew bundle --file="$file" 2>&1 | tee "$out"
                rc=${PIPESTATUS[0]}

                if [[ $rc -ne 0 ]]; then
                    warn "brew bundle ${label:-base} FALLÓ — revisa $file. Las herramientas que declara NO están instaladas."

                    # Homebrew rechaza los taps no confiados con un mensaje que
                    # no dice cómo resolverlo, y el fallo aborta el archivo
                    # entero: todo lo declarado detrás se queda sin instalar. Se
                    # traduce al comando exacto en vez de dejar al lector con el
                    # texto de brew.
                    while read -r tap; do
                        [[ -n "$tap" ]] || continue
                        warn "Causa: Homebrew no confía en el tap '$tap'. Autorízalo con:"
                        warn "    brew trust --tap $tap"
                    done < <(brew_untrusted_taps "$out")
                fi
                rm -f "$out"
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
            # unzip: lo necesitan jless y tflint para desempaquetar sus releases.
            # gnupg: lo necesita el bloque de eza de más abajo para el keyring.
            # Ninguno estaba en la lista y ambos se daban por presentes; en una
            # imagen mínima de Debian no están.
            #
            # gcc y make: nvim los necesita en Linux. nvim-treesitter compila
            # cada parser con un compilador de C, y telescope-fzf-native se
            # construye con `make`. En macOS los pone Xcode CLT; aquí no había
            # nada, así que los parsers no se instalaban y Telescope daba error
            # al cargar la extensión fzf.
            apt_install zsh tmux git curl jq yq ripgrep fd-find direnv age btop zstd unzip gnupg \
                zsh-autosuggestions zsh-syntax-highlighting bsdextrautils gcc make

            # Red y diagnóstico. Estos cuatro son C compilado contra las libs del
            # sistema y no publican binarios estáticos en GitHub, así que van por
            # apt y no por phase_binaries como el resto.
            #
            # mtr-tiny y no mtr: en Debian el paquete `mtr` arrastra GTK para su
            # frontend gráfico, inútil en un VPS headless. El binario `mtr` es el
            # mismo en ambos.
            #
            # DEBIAN_FRONTEND=noninteractive es obligatorio por tshark: su
            # postinst abre un diálogo debconf preguntando si los no-root pueden
            # capturar paquetes, y sin esto la instalación se queda colgada
            # esperando una respuesta que en CI no va a llegar nunca. La respuesta
            # por defecto (no) es la que queremos. Ya lo exporta el helper apt_install.
            apt_install mtr-tiny nmap socat iperf3 tshark

            # faketime = libfaketime del Brewfile. Es una .so que se precarga
            # con LD_PRELOAD, no un binario estático, así que va por apt igual
            # que las de red y no por phase_binaries.
            apt_install faketime

            # postgresql-client = libpq del Brewfile: da psql, pg_dump y
            # pg_isready sin instalar el servidor. Gateado como su Brewfile —
            # libpq vive en Brewfile.cloud, así que los presets --minimal y
            # --container no deben traerlo tampoco en Linux.
            if [[ $INSTALL_CLOUD -eq 1 ]]; then
                apt_install postgresql-client
            else
                warn "Skipping postgresql-client (--no-cloud)"
            fi

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

            # Neovim — el de apt suele ser muy viejo, usamos appimage como fallback.
            #
            # ARCH y no ARCH_TYPE: neovim publica nvim-linux-x86_64 y
            # nvim-linux-arm64, que no es ninguna de las dos convenciones enteras.
            # En x86_64 coinciden; en aarch64 ARCH_TYPE pedía un asset que no
            # existe y nvim no se instalaba nunca en Linux ARM.
            case "$ARCH_TYPE" in
                aarch64|arm64) NVIM_ARCH="arm64" ;;
                *)             NVIM_ARCH="$ARCH_TYPE" ;;
            esac
            NVIM_URL="https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.appimage"

            # Descarga el appimage y, si no arranca por falta de FUSE, lo extrae.
            install_nvim_appimage() {
                if ! curl -fsI "$NVIM_URL" >/dev/null 2>&1; then
                    warn "Neovim appimage no disponible para arch=$NVIM_ARCH ($NVIM_URL). Instala manualmente o usa el paquete del SO."
                    return 0
                fi
                rm -f "$LOCAL_BIN/nvim"
                curl -fsSL -o "$LOCAL_BIN/nvim" "$NVIM_URL"
                chmod +x "$LOCAL_BIN/nvim"
                if ! "$LOCAL_BIN/nvim" --version >/dev/null 2>&1; then
                    log "AppImage sin FUSE, extrayendo..."
                    # Subshell: --appimage-extract escribe en el cwd, y así el
                    # directorio nunca se filtra a las fases siguientes.
                    ( cd /tmp && rm -rf squashfs-root && "$LOCAL_BIN/nvim" --appimage-extract >/dev/null 2>&1 )
                    rm -f "$LOCAL_BIN/nvim"
                    # El rm -rf es lo que hace funcionar la actualización: si el
                    # destino ya existe, mv mete el nuevo DENTRO de él como
                    # subdirectorio y el symlink sigue apuntando al nvim viejo.
                    rm -rf "$HOME/.local/nvim-squashfs"
                    mv /tmp/squashfs-root "$HOME/.local/nvim-squashfs"
                    ln -sf "$HOME/.local/nvim-squashfs/usr/bin/nvim" "$LOCAL_BIN/nvim"
                fi
                ok "Neovim: $("$LOCAL_BIN/nvim" --version | head -1)"
            }

            if ! command -v nvim >/dev/null 2>&1; then
                log "Instalando Neovim via appimage..."
                install_nvim_appimage
            else
                NVIM_VER=$(nvim --version | head -1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+).*/\1/')
                if nvim_too_old "$NVIM_VER"; then
                    warn "Neovim $NVIM_VER es muy viejo (se necesita >=0.11). Actualizando..."
                    install_nvim_appimage
                fi
            fi

            # fd → symlink fdfind si hace falta
            if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
                ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
                ok "Symlink fd → fdfind creado"
            fi

            # eza (no está en apt por defecto)
            #
            # curl y no wget: curl ya es dependencia crítica (la valida
            # check_deps), mientras que wget no está ni en la lista de apt de
            # arriba ni entre los prerrequisitos. En una imagen mínima de Debian
            # no existe, y como esto es una tubería bajo `pipefail`, el
            # "command not found" abortaba el instalador entero en los presets
            # --vps y --container. gpg tampoco estaba: ahora se instala arriba.
            if ! command -v eza >/dev/null 2>&1; then
                log "Instalando eza..."
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
                echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] https://deb.gierens.de stable main" \
                    | sudo tee /etc/apt/sources.list.d/gierens.list
                sudo apt update -qq && sudo apt install -y eza 2>/dev/null || warn "eza no pudo instalarse"
            fi

            # bat → symlink batcat si hace falta
            if ! command -v bat >/dev/null 2>&1; then
                apt_install bat
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
