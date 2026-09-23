#!/usr/bin/env bash
# Tests de lib/verify.sh — sin instalar nada.
# Ejecutar: bash lib/verify.test.sh
#
# Se ejercita verify_tools, que decide qué filas lleva el resumen final. El
# resto de phase_verify solo imprime.

TESTS_RUN=0
TESTS_FAILED=0

check() {
    local expected=$1 name=$2; shift 2
    TESTS_RUN=$((TESTS_RUN + 1))
    if "$@"; then got=0; else got=1; fi
    if [ "$expected" = "$got" ]; then
        printf '  ✓ %s\n' "$name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  ✗ %s\n' "$name"
    fi
}

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/verify.sh
. "$LIB_DIR/verify.sh"

# ¿Aparece la herramienta $2 con el entorno $1?
lista() { ( eval "$1"; verify_tools ) | grep -qx "$2"; }

printf '\nverify_tools\n'

check 0 "las de base salen siempre" \
    lista "IS_MAC=0; ARCH_TYPE=x86_64; INSTALL_K8S=0; INSTALL_CLOUD=0" nvim
check 1 "--no-k8s no comprueba kubectl" \
    lista "IS_MAC=0; ARCH_TYPE=x86_64; INSTALL_K8S=0; INSTALL_CLOUD=1" kubectl
check 0 "con k8s sí comprueba kubectl" \
    lista "IS_MAC=0; ARCH_TYPE=x86_64; INSTALL_K8S=1; INSTALL_CLOUD=0" kubectl
check 1 "--no-cloud no comprueba tofu" \
    lista "IS_MAC=1; INSTALL_K8S=1; INSTALL_CLOUD=0" tofu
check 0 "con cloud sí comprueba tofu" \
    lista "IS_MAC=0; ARCH_TYPE=x86_64; INSTALL_K8S=0; INSTALL_CLOUD=1" tofu
check 1 "docker no se comprueba en Linux: el daemon no lo instalan estos dotfiles" \
    lista "IS_MAC=0; ARCH_TYPE=x86_64; INSTALL_K8S=1; INSTALL_CLOUD=1" docker
check 0 "docker sí se comprueba en macOS con k8s" \
    lista "IS_MAC=1; INSTALL_K8S=1; INSTALL_CLOUD=1" docker
check 1 "jless no se comprueba en Linux ARM: no hay build" \
    lista "IS_MAC=0; ARCH_TYPE=aarch64; INSTALL_K8S=0; INSTALL_CLOUD=0" jless
check 0 "jless sí en Linux x86_64" \
    lista "IS_MAC=0; ARCH_TYPE=x86_64; INSTALL_K8S=0; INSTALL_CLOUD=0" jless
check 0 "devuelve 0 aunque la última condición sea falsa (set -e en el llamador)" \
    bash -c ". '$LIB_DIR/verify.sh'; set -e; IS_MAC=0; INSTALL_K8S=1; INSTALL_CLOUD=0; verify_tools >/dev/null"

printf '\n%d/%d tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
