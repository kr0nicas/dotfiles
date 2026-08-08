#!/usr/bin/env bash
# Colores, logging, verificacion de integridad y banner.
# Cargado por install.sh. No ejecutar suelto.

# ------------------------------------------------------------------------------
# COLORES Y LOGGING
# ------------------------------------------------------------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BRIGHT_GREEN='\033[1;92m'
NC='\033[0m'

log()  { echo -e "${BLUE}  ℹ️  $*${NC}"; }
ok()   { echo -e "${GREEN}  ✅ $*${NC}"; }
warn() { echo -e "${YELLOW}  ⚠️  $*${NC}"; }
err()  { echo -e "${RED}  ❌ $*${NC}"; exit 1; }
section() { echo -e "\n${CYAN}━━━ $* ${NC}"; }

# --- Verificación de integridad ------------------------------------------------
# sha256 portable: Linux trae sha256sum, macOS trae shasum.
sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        return 1
    fi
}

# Compara un archivo contra una lista de checksums en formato "<sha256>  <nombre>".
# Códigos: 0 = coincide · 1 = NO coincide · 2 = el archivo no aparece en la lista.
# El 1 y el 2 se distinguen a propósito: "no coincide" es un incidente de
# seguridad, "no aparece" solo significa que no se pudo comprobar.
verify_sha256() {
    local file=$1 sums=$2 name expected actual
    name=$(basename "$file")
    expected=$(printf '%s\n' "$sums" \
        | awk -v n="$name" '$2 == n || $2 == "*" n { print $1; exit }')
    [[ -n "$expected" ]] || return 2
    actual=$(sha256_of "$file") || return 2
    [[ "$expected" == "$actual" ]]
}

banner() {
    printf "\n"
    printf "%b\n" "${CYAN}██╗  ██╗██████╗ ${BRIGHT_GREEN} ██████╗ ${CYAN}███╗   ██╗██╗ ██████╗ █████╗ ███████╗${NC}"
    printf "%b\n" "${CYAN}██║ ██╔╝██╔══██╗${BRIGHT_GREEN}██╔═████╗${CYAN}████╗  ██║██║██╔════╝██╔══██╗██╔════╝${NC}"
    printf "%b\n" "${CYAN}█████╔╝ ██████╔╝${BRIGHT_GREEN}██║██╔██║${CYAN}██╔██╗ ██║██║██║     ███████║███████╗${NC}"
    printf "%b\n" "${CYAN}██╔═██╗ ██╔══██╗${BRIGHT_GREEN}████╔╝██║${CYAN}██║╚██╗██║██║██║     ██╔══██║╚════██║${NC}"
    printf "%b\n" "${CYAN}██║  ██╗██║  ██║${BRIGHT_GREEN}╚██████╔╝${CYAN}██║ ╚████║██║╚██████╗██║  ██║███████║${NC}"
    printf "%b\n" "${CYAN}╚═╝  ╚═╝╚═╝  ╚═╝${BRIGHT_GREEN} ╚═════╝ ${CYAN}╚═╝  ╚═══╝╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝${NC}"
    printf "%b\n" "              ${BRIGHT_GREEN}░ SRE 2026 · dotfiles installer ░${NC}"
    printf "\n"
}
