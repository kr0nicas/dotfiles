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

        # Cuarta convención: llama `x64` a lo que uname dice x86_64 y las otras
        # tres variables llaman x86_64 o amd64. No cabe en ninguna de ellas, así
        # que tiene la suya en vez de forzar el mapeo.
        #
        # Se llamaba TERMSHARK_ARCH porque termshark era su único usuario.
        # gitleaks nombra igual (gitleaks_..._linux_x64.tar.gz), así que el
        # nombre pasa a describir la convención y no al proyecto: con el nombre
        # viejo, usarla para gitleaks parecería un copy-paste equivocado.
        case "$ARCH_TYPE" in
            x86_64)  X64_ARCH="x64"   ;;
            aarch64) X64_ARCH="arm64" ;;
            arm64)   X64_ARCH="arm64" ;;
            *)       X64_ARCH="x64"   ;;
        esac

        # Consulta la API de GitHub, autenticando si hay token en el entorno.
        #
        # Anónimo son 60 req/h por IP y este instalador gasta dos por binario
        # (una para el asset y otra para sus checksums), así que una instalación
        # completa ronda el límite y en CI —donde la IP del runner es
        # compartida— se agota casi seguro. El warning de rate-limit ya decía
        # "auth con: gh auth login", pero nunca se usaba ninguna credencial:
        # el consejo era correcto y el código lo ignoraba.
        _gh_api() {
            local url=$1 token=${GH_TOKEN:-${GITHUB_TOKEN:-}}
            if [[ -n "$token" ]]; then
                curl -fsSL -H "Authorization: Bearer $token" "$url" 2>/dev/null
            else
                curl -fsSL "$url" 2>/dev/null
            fi
        }

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
            response=$(_gh_api "https://api.github.com/repos/${repo}/releases/latest") || {
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
            response=$(_gh_api "https://api.github.com/repos/${repo}/releases/latest") || return 1
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

        # Igual que gh_latest_tar pero para releases empaquetados en zip.
        # tflint publica zip y además checksums.txt, así que se verifica igual
        # que el resto; extraer con `unzip` directo (como hace jless) se saltaría
        # esa comprobación, que es justo lo que gh_latest_tar existe para evitar.
        gh_latest_zip() {
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

            # Sin chmod posterior a propósito: el zip de tflint guarda el modo
            # 0755 y unzip lo respeta (a diferencia del tar de jless, que sí
            # necesita el chmod explícito de su instalador).
            unzip -qo "$file" -d "$dest"
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

        # X64_ARCH y no GH_ARCH ni ARCH: gitleaks publica linux_x64, no
        # linux_x86_64 (GH_ARCH) ni linux_amd64 (ARCH). Comprobado contra el
        # release real; con cualquiera de las otras dos, gh_latest_url no casa
        # ningún asset y la instalación se salta sin decir que se la saltó.
        #
        # El binario va en la raíz del tar, junto a LICENSE y README.
        install_if_missing "gitleaks" \
            "gh_latest_tar gitleaks/gitleaks 'linux_${X64_ARCH}.tar.gz\$' $LOCAL_BIN gitleaks"

        install_if_missing "sops" \
            "gh_latest_bin getsops/sops 'linux.${ARCH}' $LOCAL_BIN/sops"

        install_if_missing "dust" \
            "gh_latest_tar bootandy/dust '${ARCH_TYPE}-unknown-linux-gnu.tar.gz' $LOCAL_BIN '--strip-components=1 --wildcards */dust'"

        install_if_missing "curlie" \
            "gh_latest_tar rs/curlie 'linux_${ARCH}.tar.gz' $LOCAL_BIN curlie"

        # zoxide se baja aquí y no en phase_runtimes, que es de donde viene, por
        # una razón concreta: su instalador oficial consulta api.github.com sin
        # autenticar y el límite anónimo de 60 req/h por IP lo tumbaba en runners
        # compartidos. Ya pasó en CI. gh_latest_url sí manda GH_TOKEN cuando está
        # en el entorno, que sube el límite a 5000.
        #
        # ARCH_TYPE: triple de Rust. Y **musl**, no gnu: zoxide solo publica
        # binarios musl para Linux, al revés que ruff, delta o trippy. No publica
        # checksums, así que gh_latest_tar avisará de ello igual que con delta.
        install_if_missing "zoxide" \
            "gh_latest_tar ajeetdsouza/zoxide '${ARCH_TYPE}-unknown-linux-musl.tar.gz\$' $LOCAL_BIN zoxide"

        # ARCH_TYPE y no GH_ARCH: ruff nombra sus assets con el triple de Rust
        # (aarch64-unknown-linux-gnu), mientras que GH_ARCH traduce eso a arm64.
        # El `$` final evita matchear también el .sha256 del mismo asset; antes
        # ese papel lo hacía una comilla de cierre, que ya no está en la salida
        # de gh_asset_urls.
        install_if_missing "ruff" \
            "gh_latest_tar astral-sh/ruff '${ARCH_TYPE}-unknown-linux-gnu.tar.gz\$' $LOCAL_BIN '--strip-components=1 --wildcards */ruff'"

        # Linters de nvim-lint. En macOS los cubre el Brewfile; en Linux no los
        # tenía nadie, así que nvim-lint fallaba con ENOENT en YAML y shell igual
        # que fallaba en Python antes de ruff. El gating replica el del Brewfile:
        # los dos de abajo son base, y tflint va con el resto de IaC (cloud).
        # (No empieces un comentario con la palabra "shellcheck": la trata como
        # una directiva suya y falla el parseo del archivo entero.)
        #
        # ARCH_TYPE y no GH_ARCH: shellcheck nombra sus assets con la salida
        # cruda de uname (linux.aarch64), no con arm64.
        install_if_missing "shellcheck" \
            "gh_latest_tar koalaman/shellcheck 'linux.${ARCH_TYPE}.tar.gz' $LOCAL_BIN '--strip-components=1 --wildcards */shellcheck'"

        # yamllint es un paquete de Python y no publica binario estático, así que
        # no encaja en el patrón de gh_latest_*. Se instala con uv, que ya está
        # disponible aquí (phase_runtimes corre antes) y es como el repo gestiona
        # Python por convención. `uv tool install` lo deja aislado en su propio
        # venv y enlaza el ejecutable en ~/.local/bin, sin sudo.
        install_if_missing "yamllint" "uv tool install yamllint"

        # golangci-lint. ARCH (amd64/arm64), la convención de Go, como tflint.
        #
        # El `$` final importa: el release publica también
        # `...linux-amd64.tar.gz.sbom.json` junto al tarball, y el patrón sin
        # anclar casa los dos. Hoy sale bien de casualidad porque el tarball va
        # antes en la lista y `gh_latest_url` hace `head -1`; el día que el
        # orden cambie, `tar -xz` recibiría un JSON. El ancla lo hace
        # determinista. El binario cuelga de un directorio con el nombre
        # completo del asset, de ahí el --strip-components.
        install_if_missing "golangci-lint" \
            "gh_latest_tar golangci/golangci-lint 'linux-${ARCH}.tar.gz\$' $LOCAL_BIN '--strip-components=1 --wildcards */golangci-lint'"

        # --- Red y diagnóstico ---
        # Los cuatro que faltan aquí (mtr, nmap, socat, iperf3) van por apt en
        # phase_packages: son C contra las libs del sistema y no publican
        # binarios estáticos.
        #
        # Cada install_if_missing de este bloque gasta dos llamadas a la API de
        # GitHub (asset + checksums). Son siete, así que una instalación anónima
        # se acerca al límite de 60 req/h que ya avisa gh_latest_url. Con
        # GH_TOKEN o GITHUB_TOKEN en el entorno el límite sube a 5000 y deja de
        # importar; el CI ya lo pasa.

        # El ejecutable de trippy se llama `trip`, no `trippy`. install_if_missing
        # comprueba el comando, así que con el nombre del proyecto lo reinstalaría
        # en cada pasada creyendo que nunca está.
        #
        # ARCH_TYPE: triple de Rust (aarch64-unknown-linux-gnu). El `$` final
        # descarta las variantes musl, deb y rpm del mismo release.
        install_if_missing "trip" \
            "gh_latest_tar fujiapple852/trippy '${ARCH_TYPE}-unknown-linux-gnu.tar.gz\$' $LOCAL_BIN '--strip-components=1 --wildcards */trip'"

        # ARCH (convención de Go). El tar mete el binario en step_<versión>/bin/step,
        # de ahí el strip-components=2 en vez del 1 habitual.
        install_if_missing "step" \
            "gh_latest_tar smallstep/cli 'step_linux_.*_${ARCH}.tar.gz\$' $LOCAL_BIN '--strip-components=2 --wildcards */bin/step'"

        # ARCH_TYPE: triple de Rust. El binario va en la raíz del tar, junto a un
        # directorio assets/ con las completions que no nos interesa extraer.
        install_if_missing "bandwhich" \
            "gh_latest_tar imsnif/bandwhich '${ARCH_TYPE}-unknown-linux-gnu.tar.gz\$' $LOCAL_BIN bandwhich"

        # X64_ARCH: ver el case de arriba. Necesita `tshark` para capturar,
        # que instala phase_packages por apt.
        install_if_missing "termshark" \
            "gh_latest_tar gcla/termshark 'linux_${X64_ARCH}.tar.gz\$' $LOCAL_BIN '--strip-components=1 --wildcards */termshark'"

        # ARCH: oha publica binario suelto. El `$` es imprescindible aquí: sin él
        # el patrón casa también oha-linux-amd64-pgo, que es otra build.
        install_if_missing "oha" \
            "gh_latest_bin hatoo/oha 'oha-linux-${ARCH}\$' $LOCAL_BIN/oha"

        # ARCH_TYPE: doggo nombra con uname (doggo-linux-x86_64). El `$` descarta
        # doggo_web, que es el servidor DNS-over-HTTPS y no el cliente.
        install_if_missing "doggo" \
            "gh_latest_tar mr-karan/doggo 'doggo-linux-${ARCH_TYPE}.tar.gz\$' $LOCAL_BIN doggo"

        # lnav empaqueta el binario dentro de un directorio con la versión en el
        # nombre (lnav-0.14.0/lnav), así que gh_latest_zip a secas dejaría un
        # árbol en ~/.local/bin en vez de un ejecutable. Se extrae a un temporal
        # pasando igualmente por gh_latest_zip —para no perder la verificación de
        # checksums, que es justo lo que install_jless sí se salta— y se mueve
        # solo el binario.
        #
        # GH_ARCH: lnav nombra x86_64/arm64, que es exactamente esa variable.
        install_lnav() {
            local tmp rc
            tmp=$(mktemp -d) || return 1
            gh_latest_zip tstack/lnav "linux-musl-${GH_ARCH}.zip\$" "$tmp"
            rc=$?
            if [[ $rc -eq 0 ]]; then
                install -m 0755 "$tmp"/lnav-*/lnav "$LOCAL_BIN/lnav" || rc=1
            fi
            rm -rf "$tmp"
            return $rc
        }
        install_if_missing "lnav" "install_lnav"

        # sshuttle es Python puro y no publica binario, igual que yamllint. Mismo
        # tratamiento: uv tool install, que phase_runtimes ya dejó disponible.
        install_if_missing "sshuttle" "uv tool install sshuttle"

        # --- K8s tools (gated por --no-k8s / --minimal) ---
        if [[ $INSTALL_K8S -eq 1 ]]; then
            install_if_missing "k9s" \
                "gh_latest_tar derailed/k9s 'Linux_${ARCH}.tar.gz' $LOCAL_BIN k9s"

            install_if_missing "stern" \
                "gh_latest_tar stern/stern 'linux_${ARCH}.tar.gz' $LOCAL_BIN stern"

            # ARCH: binario suelto. kubeshark no publica checksums consolidados
            # sino un .sha256 por asset, que es el fallback que gh_checksums ya
            # tiene desde ruff — se verifica sin tocar nada.
            install_if_missing "kubeshark" \
                "gh_latest_bin kubeshark/kubeshark 'kubeshark_linux_${ARCH}\$' $LOCAL_BIN/kubeshark"

            # ARCH. Va con k8s y no en el bloque base porque replica el split del
            # Brewfile: dive inspecciona imágenes de contenedor, y sin runtime
            # instalado no hay ninguna que inspeccionar.
            install_if_missing "dive" \
                "gh_latest_tar wagoodman/dive 'linux_${ARCH}.tar.gz\$' $LOCAL_BIN dive"
        else
            warn "Skipping k9s/stern/kubeshark/dive (--no-k8s)"
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
            # tflint — linter de Terraform para nvim-lint. Va aquí y no en el
            # bloque base porque en macOS vive en Brewfile.cloud: sin Terraform
            # instalado no hay nada que lintar.
            #
            # ARCH y no ARCH_TYPE: tflint nombra sus assets con la convención de
            # Go (linux_amd64), no con la salida de uname.
            install_if_missing "tflint" \
                "gh_latest_zip terraform-linters/tflint 'linux_${ARCH}.zip' $LOCAL_BIN"

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
