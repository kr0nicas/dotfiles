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
    _gcp_adc_status "$proj" "$(_gcp_adc_quota_project)" "$cfg"
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

# quota_project_id de la ADC viva; vacío si falta el archivo, la clave o jq.
# Nunca falla: es lectura de estado para `gcx who`, no una operación.
_gcp_adc_quota_project() {
    local live
    live="$(_gcp_adc_live_path)"
    [[ -r "$live" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    jq -r '.quota_project_id // empty' "$live" 2>/dev/null
    return 0
}

# Línea de estado `adc …` para _gcp_who. Función pura (dos strings y el nombre
# de la config para el remedio): avisa solo si proyecto y quota existen ambos
# y difieren — con cualquiera de los dos vacío no hay comparación posible.
_gcp_adc_status() {
    local proj="$1" quota="$2" cfg="$3"
    if [[ -n "$proj" && -n "$quota" && "$proj" != "$quota" ]]; then
        print -r -- "  adc       $quota  ⚠ no coincide"
        print -r -- "    remedio: gcx use ${cfg:-<config>}   (o gcx adc si esta cuenta no tiene ADC guardadas)"
    else
        print -r -- "  adc       ${quota:-—}"
    fi
    return 0
}

# Parchea quota_project_id en un archivo ADC. El quota project es de la
# config, no de la cuenta: dos configs de la misma cuenta comparten ADC pero
# no quota. Temporal con umask 077 + mv en el mismo directorio: la ADC nunca
# queda a medias ni legible por otros usuarios, ni un instante.
_gcp_adc_set_quota() {
    local file="$1" project="$2" tmp
    [[ -n "$project" && -r "$file" ]] || return 0
    command -v jq >/dev/null 2>&1 || return 0
    tmp="${file}.tmp.$$"
    if ( umask 077; jq --arg p "$project" '.quota_project_id = $p' "$file" >"$tmp" 2>/dev/null ); then
        mv -f "$tmp" "$file"
    else
        rm -f "$tmp"
        return 1
    fi
}

# Guarda la ADC viva como la ADC de <cuenta>. La usa `gcx adc` tras el login.
_gcp_adc_save() {
    local account="$1" live store tmp
    live="$(_gcp_adc_live_path)"
    [[ -n "$account" && -r "$live" ]] || return 1
    store="$(_gcp_adc_store_path "$account")"
    mkdir -p "$(_gcp_adc_dir)"
    chmod 700 "$(_gcp_adc_dir)"
    tmp="${store}.tmp.$$"
    ( umask 077; cp "$live" "$tmp" ) && mv -f "$tmp" "$store"
}

# Instala la ADC guardada de <cuenta> como ADC viva y ajusta su quota project
# al proyecto de la config. Con cuenta vacía calla (el fallo visible es de la
# config); sin ADC guardada avisa y no toca nada.
_gcp_adc_install() {
    local account="$1" project="$2" store live tmp
    [[ -n "$account" ]] || return 0
    store="$(_gcp_adc_store_path "$account")"
    live="$(_gcp_adc_live_path)"
    if [[ ! -r "$store" ]]; then
        print -r -- "  ⚠ no hay ADC guardadas para $account" >&2
        print -r -- "    emítelas una vez con: gcx adc" >&2
        return 1
    fi
    mkdir -p "${live:h}"
    tmp="${live}.tmp.$$"
    { ( umask 077; cp "$store" "$tmp" ) && mv -f "$tmp" "$live"; } || {
        rm -f "$tmp"
        print -r -- "  ✗ no se pudo instalar la ADC de $account" >&2
        return 1
    }
    _gcp_adc_set_quota "$live" "$project"
}

# Emite ADC nuevas para la cuenta activa y las guarda en el almacén. Abre el
# navegador: es la única forma en que Google emite el refresh token, una vez
# por cuenta. Única función del bloque ADC sin test: envuelve al login real.
_gcp_adc_login() {
    local account project
    account="$(_gcp_active_account)"
    if [[ -z "$account" ]]; then
        print -r -- "  ✗ no hay cuenta activa. prueba: gcloud auth login" >&2
        return 1
    fi
    gcloud auth application-default login || return 1
    if ! _gcp_adc_save "$account"; then
        print -r -- "  ✗ el login no dejó ADC que guardar" >&2
        return 1
    fi
    project="$(_gcp_active_project)"
    _gcp_adc_set_quota "$(_gcp_adc_live_path)" "$project"
    print -r -- "  ↻ ADC guardadas para $account"
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
    _gcp_adc_install "$(_gcp_active_account)" "$(_gcp_active_project)"
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
    print -r -- "    gcx adc            Emite y guarda las ADC de la cuenta activa (navegador, 1 vez)"
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
    print -r -- "    · Las ADC (tofu, SDKs, apps) se guardan por cuenta y 'gcx use' las"
    print -r -- "      cambia contigo. La primera vez por cuenta: 'gcx adc'."
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
        adc)            _gcp_adc_login ;;
        -h|--help|help) _gcp_help ;;
        *)
            print -r -- "  ✗ subcomando desconocido: $1" >&2
            print -r -- "    prueba: gcx -h" >&2
            return 2
            ;;
    esac
}
