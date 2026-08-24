#!/usr/bin/env zsh
# Tests de config/zsh/gcp.zsh — solo helpers puros (sin red, sin gcloud).
# Ejecutar: zsh config/zsh/gcp.test.zsh

typeset -g TESTS_RUN=0 TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    (( TESTS_RUN++ ))
    if [[ "$expected" == "$actual" ]]; then
        print "  ✓ $name"
    else
        (( TESTS_FAILED++ ))
        print "  ✗ $name"
        print "      esperado: «$expected»"
        print "      obtenido: «$actual»"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" name="$3"
    (( TESTS_RUN++ ))
    if [[ "$haystack" == *"$needle"* ]]; then
        print "  ✓ $name"
    else
        (( TESTS_FAILED++ ))
        print "  ✗ $name"
        print "      no se encontró «$needle» en la salida"
    fi
}

# Caché aislada para los tests
export GCP_CACHE_DIR="${TMPDIR:-/tmp}/gcp-test-cache-$$"

# Config de gcloud aislada: las funciones ADC leen CLOUDSDK_CONFIG en cada
# llamada, así que apuntarla a un temporal basta para no tocar el HOME real.
export CLOUDSDK_CONFIG="${TMPDIR:-/tmp}/gcp-test-gcloud-$$"
mkdir -p "$CLOUDSDK_CONFIG"

source "${0:A:h}/gcp.zsh"

print "\n_gcp_cache_path"
assert_eq "$GCP_CACHE_DIR/projects-jorge.ochoa_itproject41.com.list" \
          "$(_gcp_cache_path 'jorge.ochoa@itproject41.com')" \
          "sanitiza la @ del email"
assert_eq "$GCP_CACHE_DIR/projects-ochoa.j_gmail.com.list" \
          "$(_gcp_cache_path 'ochoa.j@gmail.com')" \
          "cuentas distintas dan archivos distintos"
assert_eq "$GCP_CACHE_DIR/projects-raro__.list" \
          "$(_gcp_cache_path 'raro/ ')" \
          "sanitiza caracteres de ruta"

print "\n_gcp_filter_projects"
projects=$'kelova-app\tkelova-app\nsys-01877150826042451366448604\tsys\nitproject-n8n-customers\titproject-n8n-customers'
filtered="$(print -r -- "$projects" | _gcp_filter_projects)"
assert_contains "kelova-app" "$filtered" "conserva proyectos normales"
assert_contains "itproject-n8n-customers" "$filtered" "conserva proyectos con guiones"
assert_eq "2" "$(print -r -- "$filtered" | grep -c .)" "elimina exactamente los sys-*"
assert_eq "" "$(print -r -- "$filtered" | grep '^sys-')" "no queda ningún sys-*"

print "\n_gcp_use (validación de argumentos)"
out="$(_gcp_use 2>&1)"
assert_eq "2" "$?" "sin argumento devuelve código 2"
assert_contains "uso: gcx use" "$out" "sin argumento imprime el uso"
assert_contains "  ✗ uso: gcx use" "$out" \
    "el mensaje de uso sigue el estilo de error (prefijo ✗ y sangría de dos espacios)"

print "\n_gcp_use (config inexistente, sin tocar la red)"
gcloud() { print -r -- $'config-a\nconfig-b'; return 0 }
out="$(_gcp_use 'no-existe-jamas-xyz' 2>&1)"
rc=$?
unfunction gcloud
assert_eq "1" "$rc" "config inexistente devuelve código 1"
assert_contains "no existe la configuración" "$out" "config inexistente lo dice"

print "\n_gcp_use (gcloud roto se distingue de «no existe»)"
gcloud() {
    print -r -- "ERROR: (gcloud.config.configurations.list) Reauthentication failed. Cannot refresh auth tokens." >&2
    return 1
}
out="$(_gcp_use 'cualquier-config' 2>&1)"
rc=$?
unfunction gcloud
assert_eq "1" "$rc" "gcloud roto al listar devuelve código 1"
assert_contains "gcloud auth login" "$out" "gcloud roto sugiere gcloud auth login"
assert_eq "" "$(print -r -- "$out" | grep 'no existe la configuración')" \
          "gcloud roto no confunde el fallo con «no existe»"

print "\n_gcp_use (activate falla no debe quedar muda)"
gcloud() {
    case "$*" in
        "config configurations list --format=value(name)")
            print -r -- "config-stub"
            return 0
            ;;
        "config configurations activate config-stub")
            print -r -- "ERROR: (gcloud.config.configurations.activate) Reauthentication failed." >&2
            return 1
            ;;
    esac
    return 0
}
out="$(_gcp_use 'config-stub' 2>&1)"
rc=$?
unfunction gcloud
assert_eq "1" "$rc" "activate fallida devuelve código 1"
assert_contains "no se pudo activar" "$out" "activate fallida imprime un mensaje propio"
assert_contains "gcloud auth login" "$out" "activate fallida sugiere gcloud auth login"

print "\n_gcp_refresh_cache (degradación sin red)"
# Simulamos un gcloud que siempre falla, para probar el camino de error.
gcloud() { return 1 }
cache_file="$(_gcp_cache_path 'test@example.com')"

mkdir -p "$GCP_CACHE_DIR"
rm -f "$cache_file"
out="$(_gcp_refresh_cache 'test@example.com' 2>&1)"
assert_eq "1" "$?" "sin caché previa y sin red devuelve 1"
assert_contains "gcloud auth login" "$out" "sugiere autenticarse"

print -r -- $'viejo-proyecto\tviejo' > "$cache_file"
out="$(_gcp_refresh_cache 'test@example.com' 2>&1)"
assert_eq "0" "$?" "con caché previa y sin red devuelve 0"
assert_contains "caché anterior" "$out" "avisa de que usa caché vieja"
assert_contains "viejo-proyecto" "$(<"$cache_file")" "no destruye la caché previa"
unfunction gcloud

print "\n_gcp_refresh_cache (escritura atómica: reemplaza la caché, no la trunca en vivo)"
gcloud() { print -r -- $'proj1\tuno\nproj2\tdos'; return 0 }
cache_file="$(_gcp_cache_path 'atomic@example.com')"
print -r -- "viejo-contenido" > "$cache_file"
old_inode="$(ls -i "$cache_file" | awk '{print $1}')"
_gcp_refresh_cache 'atomic@example.com' >/dev/null 2>&1
new_inode="$(ls -i "$cache_file" | awk '{print $1}')"
assert_eq "1" "$(( old_inode != new_inode ))" \
    "la caché se reemplaza atómicamente (nuevo inodo vía mv), no se trunca en el mismo archivo"
unfunction gcloud
rm -f "$cache_file"

print "\n_gcp_refresh_cache (nombre de temporal único por proceso)"
gcloud() { print -r -- $'proj1\tuno\nproj2\tdos'; return 0 }
cache_file="$(_gcp_cache_path 'concurrente@example.com')"
rm -f "$cache_file"
stray_tmp="${cache_file}.tmp"
print -r -- "otro-proceso-en-vuelo" > "$stray_tmp"
_gcp_refresh_cache 'concurrente@example.com' >/dev/null 2>&1
assert_eq "otro-proceso-en-vuelo" "$(<"$stray_tmp")" \
    "no pisa el temporal fijo (sin PID) que pueda estar usando otro proceso concurrente"
unfunction gcloud
rm -f "$stray_tmp" "$cache_file"

print "\n_gcp_refresh_cache (sin archivos temporales huérfanos)"
gcloud() { print -r -- $'proj1\tuno\nproj2\tdos'; return 0 }
cache_file="$(_gcp_cache_path 'huerfanos@example.com')"
rm -f "$cache_file"
_gcp_refresh_cache 'huerfanos@example.com' >/dev/null 2>&1
leftover="$(print -rl -- "${cache_file}".*(N))"
assert_eq "" "$leftover" "refresco exitoso no deja temporales huérfanos"
unfunction gcloud

gcloud() { return 1 }
out="$(_gcp_refresh_cache 'huerfanos@example.com' 2>&1)"
rc=$?
leftover="$(print -rl -- "${cache_file}".*(N))"
assert_eq "0" "$rc" "refresco fallido con caché previa sigue devolviendo 0"
assert_eq "" "$leftover" "refresco fallido con caché previa no deja temporales huérfanos"
unfunction gcloud

rm -f "$cache_file"
gcloud() { return 1 }
out="$(_gcp_refresh_cache 'huerfanos@example.com' 2>&1)"
leftover="$(print -rl -- "${cache_file}".*(N) "${cache_file}"(N))"
assert_eq "" "$leftover" "refresco fallido sin caché previa no deja temporales huérfanos"
unfunction gcloud

print "\n_gcp_who (el estado sale de gcloud, nunca hardcodeado)"
gcloud() {
    case "$*" in
        "config configurations list --filter=is_active=true --format=value(name)")
            print -r -- "config-stub-xyz"
            ;;
        "config list --format=value(core.account)")
            print -r -- "cuenta-stub@example.com"
            ;;
        "config list --format=value(core.project)")
            print -r -- "proyecto-stub-123"
            ;;
    esac
    return 0
}
out="$(_gcp_who 2>&1)"
unfunction gcloud
assert_contains "config-stub-xyz" "$out" "la config sale del stub de gcloud"
assert_contains "cuenta-stub@example.com" "$out" "la cuenta sale del stub de gcloud"
assert_contains "proyecto-stub-123" "$out" "el proyecto sale del stub de gcloud"

print "\n_gcp_pick_config (gcloud roto no debe abrir un fzf vacío)"
gcloud() { return 1 }
fzf() { print -r -- "FZF-NO-DEBERIA-EJECUTARSE"; return 0 }
out="$(_gcp_pick_config 2>&1)"
rc=$?
unfunction gcloud fzf
assert_eq "1" "$rc" "tabla de configuraciones vacía devuelve código distinto de cero"
assert_contains "gcloud auth login" "$out" "sugiere gcloud auth login, como _gcp_pick_project"
assert_eq "" "$(print -r -- "$out" | grep 'FZF-NO-DEBERIA-EJECUTARSE')" \
    "no invoca fzf cuando la tabla viene vacía"

print "\ngcx (dispatcher)"
out="$(gcx subcomando-invalido 2>&1)"
assert_eq "2" "$?" "subcomando desconocido devuelve código 2"
assert_contains "subcomando desconocido" "$out" "nombra el subcomando inválido"

print "\n_gcp_help"
help_out="$(gcx -h 2>&1)"
assert_contains "gcx p"    "$help_out" "documenta el picker de proyectos"
assert_contains "gcx p -r" "$help_out" "documenta el refresco de caché"
assert_contains "gcx use"  "$help_out" "documenta gcx use"
assert_contains "gcx who"  "$help_out" "documenta gcx who"
assert_contains "gcpers"   "$help_out" "documenta los aliases"
assert_contains "gckel"    "$help_out" "documenta el alias nuevo"
assert_contains "$GCP_CACHE_DIR" "$help_out" "muestra la ruta real de la caché"
assert_contains "sys-"     "$help_out" "explica el filtrado de sys-*"

print "\n_gcp_adc_*_path (rutas del almacén ADC)"
assert_eq "$CLOUDSDK_CONFIG/adc" "$(_gcp_adc_dir)" \
    "el almacén cuelga de CLOUDSDK_CONFIG"
assert_eq "$CLOUDSDK_CONFIG/application_default_credentials.json" \
    "$(_gcp_adc_live_path)" "la ADC viva cuelga de CLOUDSDK_CONFIG"
assert_eq "$CLOUDSDK_CONFIG/adc/jorge.ochoa_itproject41.com.json" \
    "$(_gcp_adc_store_path 'jorge.ochoa@itproject41.com')" \
    "sanitiza la @ del email igual que _gcp_cache_path"
assert_eq "$CLOUDSDK_CONFIG/adc/raro__.json" \
    "$(_gcp_adc_store_path 'raro/ ')" "sanitiza caracteres de ruta"

print "\n_gcp_adc_quota_project"
adc_live="$(_gcp_adc_live_path)"
rm -f "$adc_live"
assert_eq "" "$(_gcp_adc_quota_project)" "sin archivo ADC devuelve vacío"
print -r -- '{"type":"authorized_user","quota_project_id":"proyecto-quota-x"}' >"$adc_live"
assert_eq "proyecto-quota-x" "$(_gcp_adc_quota_project)" \
    "lee quota_project_id de la ADC viva"
print -r -- '{"type":"authorized_user"}' >"$adc_live"
assert_eq "" "$(_gcp_adc_quota_project)" "ADC sin la clave devuelve vacío"
print -r -- 'esto no es json' >"$adc_live"
assert_eq "" "$(_gcp_adc_quota_project)" "ADC corrupta devuelve vacío, no un error"
rm -f "$adc_live"

print "\n_gcp_adc_status (puro: proyecto activo vs quota de la ADC)"
assert_eq "  adc       proyecto-a" "$(_gcp_adc_status 'proyecto-a' 'proyecto-a' 'cfg-x')" \
    "cuando coinciden, línea sin aviso"
assert_eq "  adc       —" "$(_gcp_adc_status 'proyecto-a' '' 'cfg-x')" \
    "sin quota en la ADC muestra — y no avisa"
assert_eq "  adc       proyecto-b" "$(_gcp_adc_status '' 'proyecto-b' 'cfg-x')" \
    "sin proyecto activo no hay comparación posible: sin aviso"
out="$(_gcp_adc_status 'proyecto-a' 'proyecto-b' 'cfg-x')"
assert_contains "proyecto-b  ⚠ no coincide" "$out" "en desajuste marca la línea adc"
assert_contains "gcx use cfg-x" "$out" "el remedio usa la config activa real"
assert_contains "gcx adc" "$out" "el remedio menciona gcx adc para cuentas sin ADC guardadas"

print "\n_gcp_who (incluye la línea adc)"
gcloud() {
    case "$*" in
        "config configurations list --filter=is_active=true --format=value(name)")
            print -r -- "config-stub-xyz" ;;
        "config list --format=value(core.account)")
            print -r -- "cuenta-stub@example.com" ;;
        "config list --format=value(core.project)")
            print -r -- "proyecto-stub-123" ;;
    esac
    return 0
}
adc_live="$(_gcp_adc_live_path)"
print -r -- '{"quota_project_id":"otro-proyecto-999"}' >"$adc_live"
out="$(_gcp_who 2>&1)"
rm -f "$adc_live"
unfunction gcloud
assert_contains "adc       otro-proyecto-999" "$out" "who muestra el quota de la ADC real"
assert_contains "⚠ no coincide" "$out" "who avisa cuando ADC y proyecto difieren"
assert_contains "gcx use config-stub-xyz" "$out" "el remedio de who nombra la config del stub"

print "\n_gcp_adc_set_quota (parche atómico del quota project)"
adc_live="$(_gcp_adc_live_path)"
print -r -- '{"type":"authorized_user","quota_project_id":"viejo"}' >"$adc_live"
_gcp_adc_set_quota "$adc_live" "nuevo-proyecto"
assert_eq "nuevo-proyecto" "$(jq -r '.quota_project_id' "$adc_live")" \
    "reescribe quota_project_id"
assert_eq "authorized_user" "$(jq -r '.type' "$adc_live")" \
    "no toca el resto del JSON"
assert_eq "-rw-------" "$(ls -l "$adc_live" | cut -c1-10)" \
    "el archivo parcheado queda con permisos 600"
print -r -- '{"quota_project_id":"intacto"}' >"$adc_live"
_gcp_adc_set_quota "$adc_live" ""
assert_eq "intacto" "$(jq -r '.quota_project_id' "$adc_live")" \
    "sin proyecto es un no-op"
leftover="$(print -rl -- "${adc_live}".tmp.*(N))"
assert_eq "" "$leftover" "no deja temporales huérfanos"
rm -f "$adc_live"

print "\n_gcp_adc_save (copia viva → almacén)"
print -r -- '{"refresh_token":"secreto"}' >"$adc_live"
_gcp_adc_save 'test@example.com'
adc_store="$(_gcp_adc_store_path 'test@example.com')"
assert_eq "secreto" "$(jq -r '.refresh_token' "$adc_store")" "guarda la ADC viva"
assert_eq "-rw-------" "$(ls -l "$adc_store" | cut -c1-10)" "ADC guardada con 600"
assert_eq "drwx------" "$(ls -ld "$(_gcp_adc_dir)" | cut -c1-10)" "almacén con 700"
rm -f "$adc_live"
_gcp_adc_save 'test@example.com'
assert_eq "1" "$?" "sin ADC viva devuelve 1"
assert_eq "secreto" "$(jq -r '.refresh_token' "$adc_store")" \
    "y no destruye la copia guardada"
rm -f "$adc_store"

print "\n_gcp_adc_install (almacén → ADC viva)"
adc_live="$(_gcp_adc_live_path)"
print -r -- '{"refresh_token":"de-la-cuenta-b"}' >"$(_gcp_adc_live_path)"
_gcp_adc_save 'cuenta-b@example.com'
print -r -- '{"refresh_token":"de-la-cuenta-a","quota_project_id":"viejo"}' >"$adc_live"
_gcp_adc_save 'cuenta-a@example.com'
print -r -- '{"refresh_token":"de-la-cuenta-b"}' >"$adc_live"

_gcp_adc_install 'cuenta-a@example.com' 'proyecto-de-la-config'
assert_eq "de-la-cuenta-a" "$(jq -r '.refresh_token' "$adc_live")" \
    "instala la ADC guardada de la cuenta pedida"
assert_eq "proyecto-de-la-config" "$(jq -r '.quota_project_id' "$adc_live")" \
    "ajusta el quota project al proyecto de la config"
assert_eq "-rw-------" "$(ls -l "$adc_live" | cut -c1-10)" "la ADC viva queda con 600"
assert_eq "viejo" "$(jq -r '.quota_project_id' "$(_gcp_adc_store_path 'cuenta-a@example.com')")" \
    "la copia guardada no se toca (el quota es de la config, no de la cuenta)"

_gcp_adc_install 'cuenta-b@example.com' ''
assert_eq "de-la-cuenta-b" "$(jq -r '.refresh_token' "$adc_live")" \
    "cambia de cuenta también sin proyecto"
assert_eq "null" "$(jq -r '.quota_project_id' "$adc_live")" \
    "sin proyecto no inventa quota project"

out="$(_gcp_adc_install 'sin-adc@example.com' 'proyecto-x' 2>&1)"
rc=$?
assert_eq "1" "$rc" "cuenta sin ADC guardada devuelve 1"
assert_contains "gcx adc" "$out" "y el aviso apunta a gcx adc"
assert_eq "de-la-cuenta-b" "$(jq -r '.refresh_token' "$adc_live")" \
    "y no toca la ADC viva"

_gcp_adc_install '' 'proyecto-x'
assert_eq "0" "$?" "cuenta vacía (config rota) es un no-op silencioso"
rm -f "$adc_live" "$(_gcp_adc_store_path 'cuenta-a@example.com')" \
      "$(_gcp_adc_store_path 'cuenta-b@example.com')"

rm -rf "$GCP_CACHE_DIR" "$CLOUDSDK_CONFIG"
print "\n$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN tests pasaron"
(( TESTS_FAILED == 0 ))
