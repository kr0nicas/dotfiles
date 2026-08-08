# ------------------------------------------------------------------------------
# gcp — switcher de cuentas y proyectos de Google Cloud
# ------------------------------------------------------------------------------
# Cargado desde zshrc. Requiere gcloud; los pickers requieren fzf.
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

# --- activación ---------------------------------------------------------------

_gcp_use() {
    local name="$1"
    if [[ -z "$name" ]]; then
        print -r -- "uso: gcp use <config>" >&2
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
