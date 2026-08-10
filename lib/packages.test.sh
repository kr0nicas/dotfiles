#!/usr/bin/env bash
# Tests de lib/packages.sh — sin red, sin brew y sin instalar nada.
# Ejecutar: bash lib/packages.test.sh
#
# Se ejercitan brew_untrusted_taps y packages_can_elevate. El resto del archivo
# vive dentro de phase_packages y necesitaría un sistema entero delante; esas dos
# están a nivel de archivo justamente para que esto sea posible.
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

assert_contains() {
    local haystack="$1" needle="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "$haystack" in
        *"$needle"*) printf '  ✓ %s\n' "$name" ;;
        *)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            printf '  ✗ %s\n' "$name"
            printf '      no contiene: «%s»\n' "$needle"
            printf '      en: «%s»\n' "$haystack"
            ;;
    esac
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

printf '\npackages_can_elevate\n'

# `id` y `sudo` son ejecutables externos, así que una función del mismo nombre
# los sombrea y la comprobación se puede probar entera sin root y sin tocar el
# sudoers de nadie. Cada caso corre en un subshell para no arrastrar los stubs.
rc_de() { ( eval "$1"; packages_can_elevate; echo $? ) }

assert_eq "0" "$(rc_de 'id() { echo 0; }')" \
    "root puede: no llega ni a mirar si hay sudo"

# Si fuera root y `sudo` no existiera, mirar sudo primero daría un falso negativo.
assert_eq "0" "$(rc_de 'id() { echo 0; }; PATH=/nada')" \
    "root puede aunque no haya sudo en el PATH"

# El «$1» de este stub tiene que expandirlo el stub cuando packages_can_elevate
# lo llame, no este archivo al construir la cadena — el mismo caso que los stubs
# de .githooks/hooks.test.sh, y el único sitio de este archivo donde SC2016 es
# lo que se quiere.
# shellcheck disable=SC2016
assert_eq "0" "$(rc_de 'id() { echo 1000; }; sudo() { [ "$1" = "-n" ]; }')" \
    "no-root con sudo sin contraseña puede"

# El caso que motiva la función: sudo existe pero pediría contraseña. En una caja
# de agente no hay nadie para teclearla, así que cuenta como "no puede" — si no,
# phase_packages se queda colgada en el prompt en vez de degradar.
assert_eq "1" "$(rc_de 'id() { echo 1000; }; sudo() { return 1; }')" \
    "no-root con sudo que pide contraseña NO puede"

assert_eq "1" "$(rc_de 'id() { echo 1000; }; PATH=/nada')" \
    "no-root sin sudo en el PATH no puede"

printf '\nphase_packages_if_possible (preset --agent)\n'

# Se prueba la DECISIÓN, no la instalación: phase_packages se sombrea con un
# stub que solo deja una marca. Igual que arriba, cada caso va en su subshell.
decide() {
    (
        eval "$1"
        phase_packages() { echo "CORRIÓ"; }
        section() { :; }
        warn()    { printf '%s\n' "$*"; }
        phase_packages_if_possible
    )
}

SIN_SUDO='id() { echo 1000; }; PATH=/nada'

assert_eq "CORRIÓ" "$(decide "IS_MAC=1; DRY_RUN=0; $SIN_SUDO")" \
    "en macOS corre igual: brew no usa sudo, y es la única fuente de binarios ahí"

assert_eq "CORRIÓ" "$(decide "IS_MAC=0; DRY_RUN=1; $SIN_SUDO")" \
    "en dry-run corre igual, para que el oráculo no dependa de tener sudo"

assert_eq "CORRIÓ" "$(decide "IS_MAC=0; DRY_RUN=0; id() { echo 0; }")" \
    "en Linux con root corre"

assert_contains "$(decide "IS_MAC=0; DRY_RUN=0; $SIN_SUDO")" "unzip" \
    "en Linux sin root NO corre, y dice qué debe traer la imagen base"

assert_eq "" "$(decide "IS_MAC=0; DRY_RUN=0; $SIN_SUDO" | grep '^CORRIÓ$')" \
    "y de verdad no llama a phase_packages"

printf '\n%d/%d tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
