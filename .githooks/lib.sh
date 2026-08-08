#!/usr/bin/env bash
# Helpers compartidos por los hooks. Se carga con `source`; no ejecutar suelto.
#
# Todo va a stderr: el stdout de un hook puede acabar en sitios inesperados
# según cómo lo invoque git.

# Color solo si stderr es un terminal, para no meter escapes en los logs de CI.
if [ -t 2 ]; then
    HOOK_RED=$'\033[0;31m'
    HOOK_YELLOW=$'\033[1;33m'
    HOOK_GREEN=$'\033[0;32m'
    HOOK_DIM=$'\033[2m'
    HOOK_NC=$'\033[0m'
else
    HOOK_RED=''
    HOOK_YELLOW=''
    HOOK_GREEN=''
    HOOK_DIM=''
    HOOK_NC=''
fi

hook_err()  { printf '%s✘ %s%s\n' "$HOOK_RED"    "$*" "$HOOK_NC" >&2; }
hook_warn() { printf '%s⚠ %s%s\n' "$HOOK_YELLOW" "$*" "$HOOK_NC" >&2; }
hook_ok()   { printf '%s✔ %s%s\n' "$HOOK_GREEN"  "$*" "$HOOK_NC" >&2; }
hook_info() { printf '%s  %s%s\n' "$HOOK_DIM"    "$*" "$HOOK_NC" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

# Ruta de la lista de ámbitos, junto a este archivo.
hook_scopes_file() {
    printf '%s/scopes.txt\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}
