#!/usr/bin/env bash
# Tests de los hooks de .githooks/ — sin red, sin dependencias externas.
# Ejecutar: bash .githooks/hooks.test.sh
#
# Los hooks se sourcean, no se ejecutan: cada uno solo dispara su lógica
# cuando git lo invoca (guarda BASH_SOURCE == 0 al final del archivo).

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        printf '  ✓ %s\n' "$name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  ✗ %s\n' "$name"
        printf '      esperado: «%s»\n' "$expected"
        printf '      obtenido: «%s»\n' "$actual"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "$haystack" in
        *"$needle"*)
            printf '  ✓ %s\n' "$name" ;;
        *)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            printf '  ✗ %s\n' "$name"
            printf '      no se encontró «%s» en la salida\n' "$needle" ;;
    esac
}

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=.githooks/lib.sh
. "$HOOKS_DIR/lib.sh"

printf '\nlib.sh\n'
assert_eq "0" "$(has sh; echo $?)" "has() encuentra un comando que existe"
assert_eq "1" "$(has comando-que-no-existe-jamas; echo $?)" "has() falla con uno que no"
assert_contains "roto" "$(hook_err 'algo roto' 2>&1)" "hook_err escribe a stderr"
assert_contains "✘" "$(hook_err 'x' 2>&1)" "hook_err marca el error con ✘"
assert_contains "⚠" "$(hook_warn 'x' 2>&1)" "hook_warn marca el aviso con ⚠"
assert_eq "" "$(hook_err 'x' 2>/dev/null)" "hook_err no ensucia stdout"

printf '\nscopes.txt\n'
assert_eq "0" "$(grep -qx 'iterm2' "$(hook_scopes_file)"; echo $?)" \
    "el ámbito iterm2 está en la lista"
assert_eq "0" "$(grep -qx 'gcp' "$(hook_scopes_file)"; echo $?)" \
    "el ámbito gcp está en la lista"
assert_eq "1" "$(grep -qx 'gcloud' "$(hook_scopes_file)"; echo $?)" \
    "gcloud NO está: el ámbito del dominio es gcp"

printf '\n%s/%s tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ]
