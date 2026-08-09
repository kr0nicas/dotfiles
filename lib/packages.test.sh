#!/usr/bin/env bash
# Tests de lib/packages.sh — sin red, sin brew y sin instalar nada.
# Ejecutar: bash lib/packages.test.sh
#
# Solo se ejercita brew_untrusted_taps. El resto del archivo vive dentro de
# phase_packages y necesitaría un sistema entero delante; esa función está a
# nivel de archivo justamente para que esto sea posible.
#
# Sourcear packages.sh es seguro: fuera de las dos definiciones de función no
# ejecuta nada.

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

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/packages.sh
. "$LIB_DIR/packages.sh"

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

fixture() { printf '%s\n' "$@" > "$TMP"; }

printf '\nbrew_untrusted_taps\n'

# El mensaje real que devolvió Homebrew al instalar Brewfile.cloud, que es lo
# que motivó esta función.
fixture "Error: Refusing to load formula hashicorp/tap/vault from untrusted tap hashicorp/tap."
assert_eq "hashicorp/tap" "$(brew_untrusted_taps "$TMP")" \
    "extrae el tap del mensaje real y recorta el punto final"

# El anclaje es "from untrusted tap" y no "formula", así que un cask rechazado
# tiene que reconocerse igual.
fixture "==> Fetching cosas" "Error: Refusing to load cask foo/bar/baz from untrusted tap foo/bar."
assert_eq "foo/bar" "$(brew_untrusted_taps "$TMP")" \
    "reconoce también el mensaje de un cask"

fixture "x from untrusted tap uno/tap." \
        "y from untrusted tap dos/tap." \
        "z from untrusted tap uno/tap."
assert_eq "dos/tap
uno/tap" "$(brew_untrusted_taps "$TMP")" \
    "deduplica y ordena cuando hay varios taps"

# Un fallo de brew que no sea de confianza no debe producir una sugerencia de
# brew trust: sería mandar al lector por un camino equivocado.
fixture "==> Pouring foo.bottle.tar.gz" "Error: The \`brew link\` step did not complete successfully"
assert_eq "" "$(brew_untrusted_taps "$TMP")" \
    "no inventa taps cuando el fallo es de otra cosa"

assert_eq "" "$(brew_untrusted_taps /ruta/que/no/existe)" \
    "un archivo inexistente no rompe la función"

printf '\n%d/%d tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
