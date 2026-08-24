# ------------------------------------------------------------------------------
# gcx — switcher de cuentas y proyectos de Google Cloud
# ------------------------------------------------------------------------------
# Cargado desde zshrc. Requiere gcloud; los pickers requieren fzf.
#
# El comando se llama `gcx` y no `gcp`: `gcp` es el `cp` de GNU coreutils que
# Homebrew instala con prefijo `g`, y ya vive en /usr/local/bin/gcp.
#
# Principio de diseño: ningún mensaje hardcodea cuenta ni proyecto. Todo se lee
# de gcloud, para que la salida no pueda desincronizarse de la realidad.

: ${GCP_CACHE_DIR:="$HOME/.cache/gcp"}

# --- helpers puros (sin red, sin gcloud) --------------------------------------

# Ruta del archivo de caché de una cuenta. Sanitiza cualquier carácter que no
# sea seguro en un nombre de archivo (la @ del email, sobre todo).
_gcp_cache_path() {
    local account="$1"
    print -r -- "$GCP_CACHE_DIR/projects-${account//[^a-zA-Z0-9._-]/_}.list"
}

# Filtra de stdin los proyectos sys-* que Apps Script autogenera. Son ~15 de los
# 38 visibles y hacen inservible el picker.
_gcp_filter_projects() {
    grep -v '^sys-'
}

# --- lectura de estado --------------------------------------------------------
# OJO: en `configurations list` hay que usar las rutas completas
# properties.core.account y properties.core.project. Las formas cortas
# (account, project) devuelven cadena vacía sin dar error.

_gcp_active_account() {
    gcloud config list --format='value(core.account)' 2>/dev/null
}

_gcp_active_project() {
    gcloud config list --format='value(core.project)' 2>/dev/null
}

_gcp_active_config() {
    gcloud config configurations list \
        --filter='is_active=true' --format='value(name)' 2>/dev/null
}

# Devuelve 0 si la config existe, 1 si genuinamente no existe, 2 si gcloud
# falló al consultar (sesión caducada, sin red, SDK roto...). Distinguir 1 de
# 2 es lo que permite a _gcp_use no confundir "escribiste mal el nombre" con
# "gcloud está roto".
#
# OJO: este 2 es un código interno de esta función, no el código de salida
# público de gcx. La convención pública del archivo es 2=error de uso,
# 1=error de ejecución; _gcp_use nunca deja pasar este 2 tal cual, lo mapea
# siempre a 1 (error de ejecución) antes de devolverlo al usuario.
_gcp_config_exists() {
    local list
    list="$(gcloud config configurations list --format='value(name)' 2>/dev/null)" \
        || return 2
    print -r -- "$list" | grep -qx -- "$1"
}

_gcp_who() {
    local cfg acct proj
    cfg="$(_gcp_active_config)"
    acct="$(_gcp_active_account)"
    proj="$(_gcp_active_project)"
    print -r -- "  config    ${cfg:-—}"
    print -r -- "  cuenta    ${acct:-—}"
    print -r -- "  proyecto  ${proj:-—}"
}

# --- ADC por cuenta -----------------------------------------------------------
# Las Application Default Credentials (tofu, SDKs, apps) viven en un archivo
# aparte que `gcloud config configurations activate` no toca: cambiar de config
# sin cambiarlas deja a las herramientas atacando la cuenta anterior. Guardamos
# una copia por cuenta y `gcx use` la instala al cambiar. No va en
# GCP_CACHE_DIR: son credenciales, no caché regenerable, y ~/.cache es
# candidato a limpieza.

_gcp_adc_dir() {
    print -r -- "${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/adc"
}

_gcp_adc_live_path() {
    print -r -- "${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/application_default_credentials.json"
}

_gcp_adc_store_path() {
    local account="$1"
    print -r -- "$(_gcp_adc_dir)/${account//[^a-zA-Z0-9._-]/_}.json"
}

# --- activación ---------------------------------------------------------------

_gcp_use() {
    local name="$1"
    if [[ -z "$name" ]]; then
        print -r -- "  ✗ uso: gcx use <config>" >&2
        return 2
    fi
    _gcp_config_exists "$name"
    local exists_rc=$?
    if (( exists_rc == 2 )); then
        print -r -- "  ✗ no se pudo consultar gcloud (¿sesión caducada, sin red o SDK roto?)" >&2
        print -r -- "    prueba: gcloud auth login" >&2
        return 1
    elif (( exists_rc != 0 )); then
        print -r -- "  ✗ no existe la configuración «$name»" >&2
        print -r -- "    disponibles: $(gcloud config configurations list \
            --format='value(name)' 2>/dev/null | paste -sd' ' -)" >&2
        return 1
    fi
    local activate_err
    if ! activate_err="$(gcloud config configurations activate "$name" 2>&1 >/dev/null)"; then
        print -r -- "  ✗ no se pudo activar la configuración «$name»" >&2
        [[ -n "$activate_err" ]] && print -r -- "    $activate_err" >&2
        print -r -- "    prueba: gcloud auth login" >&2
        return 1
    fi
    _gcp_who
}

# --- caché de proyectos -------------------------------------------------------
# Clave por cuenta, no por configuración: dos configs de la misma cuenta
# comparten lista, y cambiar de cuenta nunca mezcla resultados.

_gcp_refresh_cache() {
    local account="$1" cache tmp tmp_filtered n
    cache="$(_gcp_cache_path "$account")"
    # Sufijo con el PID: dos refrescos concurrentes de la misma cuenta (dos
    # terminales) no comparten nombre de temporal y no pueden pisarse.
    tmp="${cache}.tmp.$$"
    tmp_filtered="${cache}.tmp2.$$"
    mkdir -p "$GCP_CACHE_DIR"

    if gcloud projects list --format='value(projectId,name)' >"$tmp" 2>/dev/null; then
        _gcp_filter_projects <"$tmp" >"$tmp_filtered"
        rm -f "$tmp"
        # mv dentro del mismo directorio es atómico: la caché nunca queda
        # truncada a medias si el proceso se interrumpe (Ctrl-C, disco
        # lleno, terminal cerrada).
        mv -f "$tmp_filtered" "$cache"
        n="$(grep -c . <"$cache")"
        print -r -- "  ↻ $n proyectos cacheados para $account"
        return 0
    fi

    rm -f "$tmp" "$tmp_filtered"
    if [[ -s "$cache" ]]; then
        print -r -- "  ⚠ no se pudo consultar GCP; usando la caché anterior de $account" >&2
        return 0
    fi
    print -r -- "  ✗ no se pudo consultar GCP y no hay caché para $account" >&2
    print -r -- "    ¿autenticado? prueba: gcloud auth login" >&2
    return 1
}

# --- picker de proyectos ------------------------------------------------------

_gcp_pick_project() {
    local refresh=0 account cache sel proj
    [[ "$1" == "-r" || "$1" == "--refresh" ]] && refresh=1

    command -v fzf >/dev/null 2>&1 || {
        print -r -- "  ✗ gcx requiere fzf" >&2; return 1
    }

    account="$(_gcp_active_account)"
    if [[ -z "$account" ]]; then
        print -r -- "  ✗ no hay cuenta activa. prueba: gcloud auth login" >&2
        return 1
    fi

    cache="$(_gcp_cache_path "$account")"
    if (( refresh )) || [[ ! -s "$cache" ]]; then
        (( refresh )) || print -r -- "  primera carga para $account, consultando GCP..."
        _gcp_refresh_cache "$account" || return 1
    fi

    sel="$(column -t -s $'\t' <"$cache" \
        | fzf --prompt='gcx project > ' --height=40% --reverse)" || return 0
    [[ -z "$sel" ]] && return 0

    proj="${sel%% *}"
    gcloud config set project "$proj" >/dev/null 2>&1 || {
        print -r -- "  ✗ no se pudo fijar el proyecto $proj" >&2; return 1
    }
    _gcp_who
}

# --- picker de configuraciones ------------------------------------------------
# Lista TODAS las configs sin filtrar, incluida la 'default' vacía que gcloud
# exige: el picker refleja lo que gcloud tiene, sin excepciones ocultas.

# Tabla de configuraciones, alineada y con la activa marcada. Fuente única para
# el picker y para `gcx -h`.
_gcp_config_table() {
    gcloud config configurations list \
        --format='value(name,is_active,properties.core.account,properties.core.project)' 2>/dev/null \
    | awk -F'\t' '{
          printf "%s\t%s\t%s\t%s\n",
              ($2 == "True" ? "●" : "○"),
              $1,
              ($3 == "" ? "—" : $3),
              ($4 == "" ? "—" : $4)
      }' \
    | column -t -s $'\t'
}

_gcp_pick_config() {
    local table sel

    command -v fzf >/dev/null 2>&1 || {
        print -r -- "  ✗ gcx requiere fzf" >&2; return 1
    }

    # Capturamos la tabla antes de invocar fzf: si gcloud está roto o sin
    # sesión, _gcp_config_table devuelve cadena vacía y no hay que abrir un
    # picker vacío sin decir nada (gcx a secas es la invocación más común).
    table="$(_gcp_config_table)"
    if [[ -z "$table" ]]; then
        print -r -- "  ✗ no se pudo consultar gcloud. prueba: gcloud auth login" >&2
        return 1
    fi

    sel="$(print -r -- "$table" \
        | fzf --prompt='gcx config > ' --height=40% --reverse)" || return 0
    [[ -z "$sel" ]] && return 0

    # campo 1 = marca ●/○, campo 2 = nombre de la config
    _gcp_use "$(print -r -- "$sel" | awk '{print $2}')"
}

# --- ayuda --------------------------------------------------------------------

_gcp_help() {
    print -r -- ""
    print -r -- "  gcx — switcher de cuentas y proyectos de Google Cloud"
    print -r -- ""
    print -r -- "  USO"
    print -r -- "    gcx                Picker de configuraciones (cuenta + proyecto)"
    print -r -- "    gcx p              Picker de proyectos de la cuenta activa (caché, instantáneo)"
    print -r -- "    gcx p -r           Refresca la caché desde la API (~5s) y abre el picker"
    print -r -- "    gcx use <config>   Activa una configuración por nombre, sin picker"
    print -r -- "    gcx who            Config, cuenta y proyecto activos"
    print -r -- "    gcx -h             Esta referencia"
    print -r -- ""
    print -r -- "  ALIASES"
    print -r -- "    gcpers   gcx use personal      ochoa.j@gmail.com"
    print -r -- "    gcit     gcx use itproject     jorge.ochoa@itproject41.com"
    print -r -- "    gcfact   gcx use facturaya     administrator@facturayasv.com"
    print -r -- "    gckel    gcx use kelova        jorge.ochoa@itproject41.com"
    print -r -- "    gcwho    gcx who"
    print -r -- ""
    print -r -- "  CÓMO FUNCIONA"
    print -r -- "    · El proyecto de cada config es solo dónde aterrizas: 'gcx p' salta a"
    print -r -- "      cualquier otro proyecto sin cambiar de cuenta."
    print -r -- "    · La caché es por cuenta, no por config:"
    print -r -- "        $GCP_CACHE_DIR/projects-<cuenta>.list"
    print -r -- "      Cambiar de config nunca mezcla listas."
    print -r -- "    · Los proyectos sys-* (autogenerados por Apps Script) se ocultan."
    print -r -- "    · Los mensajes se leen de gcloud, nunca están hardcodeados: no pueden"
    print -r -- "      desincronizarse de la realidad."
    print -r -- "    · Cancelar el fzf con Esc no cambia nada."
    print -r -- ""
    print -r -- "  CONFIGURACIONES ACTUALES"
    _gcp_config_table | sed 's/^/    /'
    print -r -- ""
}

# --- punto de entrada ---------------------------------------------------------

gcx() {
    case "$1" in
        '')             _gcp_pick_config ;;
        p|project)      shift; _gcp_pick_project "$@" ;;
        use)            shift; _gcp_use "$@" ;;
        who)            _gcp_who ;;
        -h|--help|help) _gcp_help ;;
        *)
            print -r -- "  ✗ subcomando desconocido: $1" >&2
            print -r -- "    prueba: gcx -h" >&2
            return 2
            ;;
    esac
}
