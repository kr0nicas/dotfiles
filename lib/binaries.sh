#!/usr/bin/env bash
# Fase: binarios SRE desde GitHub Releases (solo Linux), con checksums.
# Cargado por install.sh. No ejecutar suelto.

phase_binaries() {
    # ------------------------------------------------------------------------------
    # 6b. HERRAMIENTAS SRE (binarios — solo Linux, en Mac vienen del Brewfile)
    # ------------------------------------------------------------------------------
    if [[ $IS_MAC -eq 0 ]]; then
        section "Herramientas SRE (Linux)"

        # Mapeo de arquitectura para proyectos que usan x86_64/arm64
        case "$ARCH_TYPE" in
            x86_64)  GH_ARCH="x86_64" ;;
            aarch64) GH_ARCH="arm64"   ;;
            arm64)   GH_ARCH="arm64"   ;;
            *)       GH_ARCH="x86_64"  ;;
        esac

        # Extrae las URLs de descarga de una respuesta de la API, una por línea.
        #
        # La API NO garantiza el JSON indentado: koalaman/shellcheck lo devuelve
        # minificado en una sola línea, mientras que ruff, delta o tflint vienen
        # con un asset por línea. Filtrar con `grep <patrón>` asume lo segundo:
        # sobre una respuesta minificada el patrón casa el documento entero y el
        # `sed` —que es greedy— devuelve el ÚLTIMO asset del release en vez del
        # que se pidió. Silencioso y con la arquitectura equivocada.
        #
        # `grep -o` deja una URL por línea en ambos formatos, así que el filtrado
        # posterior se comporta igual venga como venga la respuesta.
        gh_asset_urls() {
            printf '%s' "$1" \
                | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' \
                | sed 's/.*"browser_download_url":[[:space:]]*"//;s/"$//'
        }

        # Helper: descarga el último release de GitHub sin hardcodear versión
        # Compatible con Linux y macOS (sin grep -P)
        # Detecta rate-limit (60 req/h anónimo) y emite warning legible.
        gh_latest_url() {
            local repo=$1 pattern=$2
            local response
            response=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null) || {
                warn "GitHub API falló para $repo (¿rate-limit? auth con: gh auth login). Saltando."
                return 1
            }
            if [[ "$response" == *"API rate limit exceeded"* ]] || [[ "$response" == *"rate limit"* ]]; then
                warn "GitHub API rate-limit alcanzado (60 req/h anónimo). Auth: gh auth login. Saltando $repo."
                return 1
            fi
            gh_asset_urls "$response" | grep "$pattern" | head -1
        }

        # Descarga el archivo de checksums de un release, si el proyecto publica uno.
        # No todos lo hacen (delta y dust, por ejemplo, no publican ninguno), así que
        # fallar aquí es normal y no es un error: significa "no hay nada que comparar".
        gh_checksums() {
            local repo=$1 asset=${2:-} response url
            response=$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null) || return 1
            url=$(gh_asset_urls "$response" \
                | grep -iE 'checksums?\.txt|sha256sums?|SHA256SUMS' | head -1)
            # Algunos proyectos (ruff) no publican un archivo consolidado sino un
            # .sha256 por asset. Sin este fallback caeríamos en el warning de "no
            # publica checksums", que además de falso deja el binario sin verificar.
            #
            # La comparación es sobre el basename y no un grep del patrón: así
            # "<asset>.sha256" casa exacto y no por subcadena.
            if [[ -z "$url" && -n "$asset" ]]; then
                local candidate
                while read -r candidate; do
                    if [[ "$(basename "$candidate")" == "${asset}.sha256" ]]; then
                        url=$candidate
                        break
                    fi
                done < <(gh_asset_urls "$response")
            fi
            [[ -n "$url" ]] || return 1
            curl -fsSL "$url" 2>/dev/null
        }

        # Descarga a disco, verifica contra los checksums del release cuando existen,
        # y solo entonces extrae. Antes hacía `curl | tar`, que no deja nada que
        # comprobar. Un checksum que NO coincide aborta la instalación entera: es la
        # única señal que distingue una descarga corrupta de una manipulada.
        gh_latest_tar() {
            local repo=$1 pattern=$2 dest=$3 extra_tar_args=${4:-}
            local url tmp file sums rc
            url=$(gh_latest_url "$repo" "$pattern")
            [[ -n "$url" ]] || return 1

            tmp=$(mktemp -d) || return 1
            file="$tmp/$(basename "$url")"
            curl -fsSL -o "$file" "$url" || { rm -rf "$tmp"; return 1; }

            if sums=$(gh_checksums "$repo" "$(basename "$file")"); then
                verify_sha256 "$file" "$sums" && rc=0 || rc=$?
                case $rc in
                    0) ok "checksum verificado: $(basename "$file")" ;;
                    1) rm -rf "$tmp"
                       err "CHECKSUM NO COINCIDE en $(basename "$file") ($repo). Descarga corrupta o manipulada — abortando." ;;
                    *) warn "$repo publica checksums pero $(basename "$file") no aparece en la lista; instalado sin verificar" ;;
                esac
            else
                warn "$repo no publica checksums en su release; $(basename "$file") instalado sin verificar"
            fi

            # shellcheck disable=SC2086  # extra_tar_args son flags, deben expandirse
            tar -xz -C "$dest" -f "$file" $extra_tar_args
            rc=$?
            rm -rf "$tmp"
            return $rc
        }

        # Igual que gh_latest_tar pero para binarios sueltos (sin tar).
        gh_latest_bin() {
            local repo=$1 pattern=$2 dest=$3
            local url tmp file sums rc
            url=$(gh_latest_url "$repo" "$pattern")
            [[ -n "$url" ]] || return 1

            tmp=$(mktemp -d) || return 1
            file="$tmp/$(basename "$url")"
            curl -fsSL -o "$file" "$url" || { rm -rf "$tmp"; return 1; }

            if sums=$(gh_checksums "$repo" "$(basename "$file")"); then
                verify_sha256 "$file" "$sums" && rc=0 || rc=$?
                case $rc in
                    0) ok "checksum verificado: $(basename "$file")" ;;
                    1) rm -rf "$tmp"
                       err "CHECKSUM NO COINCIDE en $(basename "$file") ($repo). Descarga corrupta o manipulada — abortando." ;;
                    *) warn "$repo publica checksums pero $(basename "$file") no aparece en la lista; instalado sin verificar" ;;
                esac
            else
                warn "$repo no publica checksums en su release; $(basename "$file") instalado sin verificar"
            fi

            install -m 0755 "$file" "$dest"
            rc=$?
            rm -rf "$tmp"
            return $rc
        }

        # --- Always: dev ergonomics + security (no gating) ---
        install_if_missing "lazygit" \
            "gh_latest_tar jesseduffield/lazygit 'linux_${GH_ARCH}.tar.gz' $LOCAL_BIN lazygit"

        install_if_missing "delta" \
            "gh_latest_tar dandavison/delta '${ARCH_TYPE}-unknown-linux-gnu.tar.gz' $LOCAL_BIN '--strip-components=1 --wildcards */delta'"

        install_if_missing "trivy" \
            "curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b $LOCAL_BIN"

        install_if_missing "sops" \
            "gh_latest_bin getsops/sops 'linux.${ARCH}' $LOCAL_BIN/sops"

        install_if_missing "dust" \
            "gh_latest_tar bootandy/dust '${ARCH_TYPE}-unknown-linux-gnu.tar.gz' $LOCAL_BIN '--strip-components=1 --wildcards */dust'"

        install_if_missing "curlie" \
            "gh_latest_tar rs/curlie 'linux_${ARCH}.tar.gz' $LOCAL_BIN curlie"

        # ARCH_TYPE y no GH_ARCH: ruff nombra sus assets con el triple de Rust
        # (aarch64-unknown-linux-gnu), mientras que GH_ARCH traduce eso a arm64.
        # El `$` final evita matchear también el .sha256 del mismo asset; antes
        # ese papel lo hacía una comilla de cierre, que ya no está en la salida
        # de gh_asset_urls.
        install_if_missing "ruff" \
            "gh_latest_tar astral-sh/ruff '${ARCH_TYPE}-unknown-linux-gnu.tar.gz\$' $LOCAL_BIN '--strip-components=1 --wildcards */ruff'"

        # --- K8s tools (gated por --no-k8s / --minimal) ---
        if [[ $INSTALL_K8S -eq 1 ]]; then
            install_if_missing "k9s" \
                "gh_latest_tar derailed/k9s 'Linux_${ARCH}.tar.gz' $LOCAL_BIN k9s"

            install_if_missing "stern" \
                "gh_latest_tar stern/stern 'linux_${ARCH}.tar.gz' $LOCAL_BIN stern"
        else
            warn "Skipping k9s/stern (--no-k8s)"
        fi

        install_jless() {
            local url
            url=$(gh_latest_url PaulJuliusMartinez/jless "${GH_ARCH}-unknown-linux-gnu.zip")
            if [[ -n "$url" ]]; then
                curl -fsSL "$url" -o /tmp/jless.zip && unzip -qo /tmp/jless.zip -d "$LOCAL_BIN" && rm -f /tmp/jless.zip
                chmod +x "$LOCAL_BIN/jless"
            else
                return 1
            fi
        }
        install_if_missing "jless" "install_jless"

        # --- K8s core (gated por --no-k8s / --minimal) ---
        if [[ $INSTALL_K8S -eq 1 ]]; then
            # kubectl — latest stable
            if ! command -v kubectl >/dev/null 2>&1; then
                log "Instalando kubectl..."
                if [[ $DRY_RUN -eq 0 ]]; then
                    KUBECTL_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
                    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${ARCH}/kubectl" \
                        -o "$LOCAL_BIN/kubectl" && chmod +x "$LOCAL_BIN/kubectl" \
                        && ok "kubectl ${KUBECTL_VER} instalado" \
                        || warn "kubectl no pudo instalarse, continúa manualmente."
                else
                    warn "DRY-RUN: kubectl install omitido"
                fi
            else
                ok "kubectl ya instalado ($(kubectl version --client --short 2>/dev/null | head -1))"
            fi

            # helm — latest stable
            if ! command -v helm >/dev/null 2>&1; then
                log "Instalando helm..."
                if [[ $DRY_RUN -eq 0 ]]; then
                    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash \
                        && ok "helm instalado" \
                        || warn "helm no pudo instalarse, continúa manualmente."
                else
                    warn "DRY-RUN: helm install omitido"
                fi
            else
                ok "helm ya instalado ($(helm version --short 2>/dev/null))"
            fi

            # kubectx / kubens
            if ! command -v kubectx >/dev/null 2>&1; then
                log "Instalando kubectx/kubens..."
                if [[ $DRY_RUN -eq 0 ]]; then
                    gh_latest_tar ahmetb/kubectx "kubectx_v.*_linux_${GH_ARCH}.tar.gz" "$LOCAL_BIN" kubectx \
                        || warn "kubectx no pudo instalarse, continúa manualmente."
                    gh_latest_tar ahmetb/kubectx "kubens_v.*_linux_${GH_ARCH}.tar.gz" "$LOCAL_BIN" kubens \
                        || warn "kubens no pudo instalarse, continúa manualmente."
                    command -v kubectx >/dev/null 2>&1 && ok "kubectx/kubens instalados"
                else
                    warn "DRY-RUN: kubectx install omitido"
                fi
            else
                ok "kubectx ya instalado"
            fi
        else
            warn "Skipping kubectl/helm/kubectx (--no-k8s)"
        fi

        # --- Cloud / IaC (gated por --no-cloud / --minimal) ---
        if [[ $INSTALL_CLOUD -eq 1 ]]; then
            # OpenTofu — latest stable (reemplazo open source de Terraform)
            if ! command -v tofu >/dev/null 2>&1; then
                log "Instalando OpenTofu..."
                if [[ $DRY_RUN -eq 0 ]]; then
                    TOFU_VER=$(curl -fsSL https://api.github.com/repos/opentofu/opentofu/releases/latest \
                        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
                    TOFU_URL="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VER}/tofu_${TOFU_VER}_linux_${ARCH}.tar.gz"
                    curl -fsSL "$TOFU_URL" | tar -xz -C "$LOCAL_BIN" tofu \
                        && ok "OpenTofu v${TOFU_VER} instalado" \
                        || warn "OpenTofu no pudo instalarse, continúa manualmente."
                else
                    warn "DRY-RUN: OpenTofu install omitido"
                fi
            else
                ok "OpenTofu ya instalado ($(tofu version | head -1))"
            fi
        else
            warn "Skipping OpenTofu (--no-cloud)"
        fi
    fi

}
