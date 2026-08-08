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

printf '\ncommit-msg\n'
# shellcheck source=.githooks/commit-msg
. "$HOOKS_DIR/commit-msg"

MSG_TMP="${TMPDIR:-/tmp}/hooks-test-msg-$$"
check_msg() { printf '%s\n' "$1" > "$MSG_TMP"; validate_commit_msg "$MSG_TMP" 2>&1; }
check_rc()  { printf '%s\n' "$1" > "$MSG_TMP"; validate_commit_msg "$MSG_TMP" >/dev/null 2>&1; echo $?; }

assert_eq "0" "$(check_rc 'feat(iterm2): perfil dinámico SRE 2026')" "acepta tipo+ámbito+asunto"
assert_eq "0" "$(check_rc 'docs: documentar la fuente por plataforma')" "acepta sin ámbito"
assert_eq "0" "$(check_rc 'fix(zshrc): quitar alias que rompía du')" "acepta acentos en el asunto"
assert_eq "0" "$(check_rc 'feat(gcp)!: cambiar el nombre del comando')" "acepta el ! de breaking change"

assert_eq "1" "$(check_rc 'Update dots: 2026-07-24')" "rechaza el formato viejo de dots"
assert_eq "1" "$(check_rc 'arreglar el prompt')" "rechaza mensaje sin tipo"
assert_eq "1" "$(check_rc 'feature(iterm2): perfil')" "rechaza tipo desconocido"
assert_eq "1" "$(check_rc 'feat(gcloud): algo')" "rechaza ámbito fuera de la lista"
assert_eq "1" "$(check_rc 'feat(iterm2): Perfil dinámico')" "rechaza asunto en mayúscula"
assert_eq "1" "$(check_rc 'feat(iterm2): perfil dinámico.')" "rechaza punto final"
assert_eq "1" "$(check_rc '')" "rechaza mensaje vacío"
assert_eq "1" "$(check_rc "feat(repo): $(printf 'x%.0s' $(seq 1 80))")" "rechaza asunto de más de 72"

assert_eq "0" "$(check_rc "Merge pull request #12 from kr0nicas/feat/iterm2")" "exime los merges"
assert_eq "0" "$(check_rc 'Revert "feat(iterm2): perfil dinámico"')" "exime los reverts"
assert_eq "0" "$(check_rc 'fixup! feat(iterm2): perfil dinámico')" "exime los fixup!"

assert_contains "gcloud" "$(check_msg 'feat(gcloud): algo')" "el error nombra el ámbito inválido"
assert_contains "scopes.txt" "$(check_msg 'feat(gcloud): algo')" "el error dice dónde añadirlo"
assert_contains "feature" "$(check_msg 'feature(iterm2): x')" "el error nombra el tipo inválido"
assert_contains "72" "$(check_msg "feat(repo): $(printf 'x%.0s' $(seq 1 80))")" "el error cita el límite"

rm -f "$MSG_TMP"

printf '\n%s/%s tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ]
