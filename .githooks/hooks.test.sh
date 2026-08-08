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
assert_eq "0" "$(check_rc 'fix(zshrc): nota: revisar el README')" "acepta un segundo «: » en el asunto"
assert_eq "0" "$(check_rc 'fix(zshrc): nota: Revisar el README')" \
    "el chequeo de mayúscula mira el asunto, no la línea entera"

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
assert_eq "0" "$(check_rc 'squash! feat(iterm2): perfil dinámico')" "exime los squash!"

assert_contains "gcloud" "$(check_msg 'feat(gcloud): algo')" "el error nombra el ámbito inválido"
assert_contains "scopes.txt" "$(check_msg 'feat(gcloud): algo')" "el error dice dónde añadirlo"
assert_contains "feature" "$(check_msg 'feature(iterm2): x')" "el error nombra el tipo inválido"
assert_contains "72" "$(check_msg "feat(repo): $(printf 'x%.0s' $(seq 1 80))")" "el error cita el límite"

rm -f "$MSG_TMP"

printf '\npre-commit — lint\n'
# shellcheck source=.githooks/pre-commit
. "$HOOKS_DIR/pre-commit"

LINT_TMP="${TMPDIR:-/tmp}/hooks-test-lint-$$"
mkdir -p "$LINT_TMP"

printf 'esto no es json\n' > "$LINT_TMP/roto.json"
printf '{"ok": true}\n'    > "$LINT_TMP/bueno.json"

if has python3; then
    assert_eq "1" "$(lint_staged "$LINT_TMP/roto.json" >/dev/null 2>&1; echo $?)" \
        "rechaza un JSON inválido"
    assert_eq "0" "$(lint_staged "$LINT_TMP/bueno.json" >/dev/null 2>&1; echo $?)" \
        "acepta un JSON válido"
    assert_contains "roto.json" "$(lint_staged "$LINT_TMP/roto.json" 2>&1)" \
        "el error nombra el archivo"
else
    printf '  — python3 ausente, tests de JSON omitidos\n'
fi

# Degradación: con la herramienta fuera del PATH debe avisar, no bloquear.
degradado_rc="$(PATH=/nonexistent lint_staged "$LINT_TMP/roto.json" >/dev/null 2>&1; echo $?)"
assert_eq "0" "$degradado_rc" "sin herramientas disponibles deja pasar"
assert_contains "⚠" "$(PATH=/nonexistent lint_staged "$LINT_TMP/roto.json" 2>&1)" \
    "sin herramientas disponibles avisa"

assert_eq "0" "$(lint_staged "$LINT_TMP/no-existe.json" >/dev/null 2>&1; echo $?)" \
    "ignora archivos que ya no existen (borrados en el índice)"

STUB_DIR="${TMPDIR:-/tmp}/hooks-test-stub-$$"
STUB_LOG="$STUB_DIR/args.log"
export STUB_LOG
mkdir -p "$STUB_DIR"
# El stub REGISTRA sus argumentos además de fallar. Sin el registro, un test que
# solo mira el código de salida pasa igual con el bug: el código viejo mandaba
# «shellcheck install.sh» pasara lo que pasara, y un stub que siempre sale 1
# habría dado rc=1 en ambas versiones. Lo que discrimina es QUÉ archivo recibe.
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >> "$STUB_LOG"\nexit 1\n' > "$STUB_DIR/shellcheck"
chmod +x "$STUB_DIR/shellcheck"

assert_eq "1" "$(PATH="$STUB_DIR:$PATH" lint_staged '.githooks/commit-msg' >/dev/null 2>&1; echo $?)" \
    "analiza los hooks, que no llevan extensión .sh"
assert_eq "1" "$(PATH="$STUB_DIR:$PATH" lint_staged 'config/bin/cn' >/dev/null 2>&1; echo $?)" \
    "analiza config/bin/cn, que tampoco lleva extensión"
assert_eq "0" "$(PATH="$STUB_DIR:$PATH" lint_staged 'README.md' >/dev/null 2>&1; echo $?)" \
    "no manda a shellcheck lo que no es un script"

: > "$STUB_LOG"
PATH="$STUB_DIR:$PATH" lint_staged 'scripts/github-topics-manager.sh' >/dev/null 2>&1
assert_contains "scripts/github-topics-manager.sh" "$(cat "$STUB_LOG")" \
    "shellcheck recibe el script staged, no install.sh por delegación"

: > "$STUB_LOG"
PATH="$STUB_DIR:$PATH" lint_staged 'lib/symlinks.sh' >/dev/null 2>&1
assert_contains "install.sh" "$(cat "$STUB_LOG")" \
    "un lib/ staged sí delega en install.sh"
assert_contains "-x" "$(cat "$STUB_LOG")" \
    "el análisis de install.sh usa -x para arrastrar lib/"

rm -rf "$STUB_DIR"

rm -rf "$LINT_TMP"

printf '\npre-commit — secretos\n'
SEC_TMP="${TMPDIR:-/tmp}/hooks-test-sec-$$"
mkdir -p "$SEC_TMP/.ssh"

printf 'contenido cualquiera\n' > "$SEC_TMP/.ssh/id_rsa"
printf 'contenido cualquiera\n' > "$SEC_TMP/cert.pem"
printf 'AWS_KEY=AKIAIOSFODNN7EXAMPLE\n' > "$SEC_TMP/config.env.txt"
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\n' > "$SEC_TMP/inocente.txt"
printf 'export TOKEN=ghp_0123456789abcdefghijklmnopqrstuvwxyz\n' > "$SEC_TMP/notas.md"
printf '# dotfiles\nnada sensible aquí\n' > "$SEC_TMP/README.md"

assert_eq "1" "$(scan_secrets "$SEC_TMP/.ssh/id_rsa" >/dev/null 2>&1; echo $?)" \
    "bloquea por nombre: id_rsa"
assert_eq "1" "$(scan_secrets "$SEC_TMP/cert.pem" >/dev/null 2>&1; echo $?)" \
    "bloquea por nombre: .pem"
assert_eq "1" "$(scan_secrets "$SEC_TMP/config.env.txt" >/dev/null 2>&1; echo $?)" \
    "bloquea por contenido: clave de AWS"
assert_eq "1" "$(scan_secrets "$SEC_TMP/inocente.txt" >/dev/null 2>&1; echo $?)" \
    "bloquea por contenido: cabecera de clave privada"
assert_eq "1" "$(scan_secrets "$SEC_TMP/notas.md" >/dev/null 2>&1; echo $?)" \
    "bloquea por contenido: token de GitHub"
assert_eq "0" "$(scan_secrets "$SEC_TMP/README.md" >/dev/null 2>&1; echo $?)" \
    "deja pasar un archivo limpio"

assert_contains "id_rsa" "$(scan_secrets "$SEC_TMP/.ssh/id_rsa" 2>&1)" \
    "el error nombra el archivo"
assert_contains "--no-verify" "$(scan_secrets "$SEC_TMP/.ssh/id_rsa" 2>&1)" \
    "el error explica cómo saltárselo a propósito"

# No degrada nunca: sigue bloqueando aunque no haya nada en el PATH.
assert_eq "1" "$(PATH=/nonexistent scan_secrets "$SEC_TMP/.ssh/id_rsa" >/dev/null 2>&1; echo $?)" \
    "el barrido de secretos no degrada"

printf 'AWS_KEY=AKIAIOSFODNN7EXAMPLE\n' > "$SEC_TMP/nombre con espacios.txt"
assert_eq "1" "$(scan_secrets "$SEC_TMP/nombre con espacios.txt" >/dev/null 2>&1; echo $?)" \
    "detecta secretos en archivos con espacios en el nombre"

rm -rf "$SEC_TMP"

printf '\n%s/%s tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ]
