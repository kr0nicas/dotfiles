#!/usr/bin/env bash
# Tests de config/claude/settings.json — sin red y sin Claude Code delante.
# Ejecutar: bash config/claude/settings.test.sh
#
# Este archivo se symlinkea a ~/.claude/settings.json en TODAS las plataformas,
# pero declara un hook PreToolUse que invoca `rtk`, y rtk solo existe en macOS:
# su fórmula de Homebrew no tiene bottle de Linux y lib/binaries.sh no lo
# instala. Sin guardar, el hook corría un binario inexistente en cada llamada
# Bash de cualquier Linux.
#
# Lo que se comprueba no es el texto del comando sino su COMPORTAMIENTO: que
# salga 0 y en silencio donde rtk no existe. Así el test sigue valiendo si el
# comando se reescribe de otra forma.

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

DIR="$(cd "$(dirname "$0")" && pwd)"
SETTINGS="$DIR/settings.json"
[ -f "$SETTINGS" ] || { printf '  ✗ no se encontró %s\n' "$SETTINGS"; exit 1; }

printf '\nsettings.json · validez\n'

assert_eq "0" "$(python3 -m json.tool "$SETTINGS" >/dev/null 2>&1; echo $?)" \
    "es JSON válido"

# El comando se extrae del propio archivo: copiarlo aquí dejaría el test
# pasando en verde sobre un settings.json que ya dice otra cosa.
CMD=$(python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
for grupo in d.get("hooks", {}).get("PreToolUse", []):
    for h in grupo.get("hooks", []):
        if "rtk" in h.get("command", ""):
            print(h["command"])
            sys.exit(0)
' "$SETTINGS")

assert_eq "0" "$([ -n "$CMD" ] && echo 0 || echo 1)" \
    "el hook PreToolUse de rtk sigue declarado"

printf '\nhook de rtk · degradación donde rtk no existe\n'

# PATH reducido: rtk vive en /usr/local/bin (macOS) o ~/.local/bin (Linux), así
# que /bin:/usr/bin reproduce una caja sin rtk sin desinstalar nada.
SIN_RTK="/bin:/usr/bin"

# Cinturón: si el entorno de CI tuviera rtk en /usr/bin, el escenario no sería
# el que se quiere probar y el test mentiría.
if env PATH="$SIN_RTK" command -v rtk >/dev/null 2>&1; then
    printf '  ✗ rtk está en %s; este test no puede simular su ausencia\n' "$SIN_RTK"
    exit 1
fi

salida=$(env PATH="$SIN_RTK" sh -c "$CMD" 2>&1 </dev/null)
codigo=$?

# Un PreToolUse que sale != 0 es un error de hook en cada llamada Bash. Antes
# del guardado esto era 127 y «rtk: command not found» en cada una.
assert_eq "0" "$codigo" \
    "sale 0 sin rtk, en vez de 127 en cada llamada Bash"
assert_eq "" "$salida" \
    "no imprime nada sin rtk"

printf '\n'
if [ "$TESTS_FAILED" -gt 0 ]; then
    printf '%s/%s tests pasaron — %s fallaron\n' \
        "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN" "$TESTS_FAILED"
    exit 1
fi
printf '%s/%s tests pasaron\n' "$TESTS_RUN" "$TESTS_RUN"
