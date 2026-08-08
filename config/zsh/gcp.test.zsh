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
assert_contains "uso: gcp use" "$out" "sin argumento imprime el uso"

out="$(_gcp_use 'no-existe-jamas-xyz' 2>&1)"
assert_eq "1" "$?" "config inexistente devuelve código 1"
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

rm -rf "$GCP_CACHE_DIR"
print "\n$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN tests pasaron"
(( TESTS_FAILED == 0 ))
