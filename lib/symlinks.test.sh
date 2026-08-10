#!/usr/bin/env bash
# Tests de lib/symlinks.sh — sin tocar el HOME real y sin crear ni un symlink.
# Ejecutar: bash lib/symlinks.test.sh
#
# Todo corre con DRY_RUN=1 y HOME apuntando a un temporal: safe_link y safe_mkdir
# en modo dry-run no escriben nada, así que la suite es segura de correr en la
# máquina de trabajo. Los tests leen justamente esa salida de dry-run —
# «DRY-RUN: ln -sf <fuente> → <destino>»— para saber qué habría enlazado cada
# grupo. Es la misma salida que install.sh usa como oráculo.
#
# Lo que esta suite protege:
#   - que el preset --agent enlace ~/.claude y NADA más (es su razón de ser);
#   - que partir phase_symlinks en grupos no deje ninguno huérfano, que es el
#     modo de fallo del refactor: un grupo definido y nunca llamado no rompe
#     nada visible, solo deja de enlazar en silencio.
#
# Sourcear symlinks.sh es seguro: fuera de las definiciones no ejecuta nada.

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

assert_not_contains() {
    local haystack="$1" needle="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "$haystack" in
        *"$needle"*)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            printf '  ✗ %s\n' "$name"
            printf '      contiene lo que no debía: «%s»\n' "$needle"
            printf '      en: «%s»\n' "$haystack"
            ;;
        *) printf '  ✓ %s\n' "$name" ;;
    esac
}

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTFILES_DIR="$(cd "$LIB_DIR/.." && pwd)"

# HOME de mentira: ningún destino de la suite apunta al HOME real.
FAKE_HOME=$(mktemp -d)
trap 'rm -rf "$FAKE_HOME"' EXIT
HOME="$FAKE_HOME"

DRY_RUN=1

# Logging de mentira, en texto plano y sin colores para poder compararlo.
# `section` se prefija para poder filtrarlo: es la única línea que distingue
# phase_symlinks de la suma de sus grupos.
log()     { printf '%s\n' "$*"; }
ok()      { printf '%s\n' "$*"; }
warn()    { printf '%s\n' "$*"; }
section() { printf 'SECTION: %s\n' "$*"; }

# shellcheck source=lib/symlinks.sh
. "$LIB_DIR/symlinks.sh"

# Corre una función y devuelve su salida sin las líneas de sección.
run_group() { "$@" 2>&1 | grep -v '^SECTION: '; }

# Destinos que una función habría enlazado, uno por línea.
dests() { run_group "$@" | sed -n 's/^DRY-RUN: ln -sf .* → //p'; }

printf '\nsymlinks_claude\n'

assert_eq "$FAKE_HOME/.claude/settings.json
$FAKE_HOME/.claude/statusline.sh
$FAKE_HOME/.claude/CLAUDE.md" "$(dests symlinks_claude)" \
    "enlaza los tres archivos de ~/.claude y ninguno más"

assert_contains "$(run_group symlinks_claude)" "sembraría ~/.claude/settings.local.json" \
    "siembra settings.local.json cuando no existe"

printf '\nphase_symlinks_agent (preset --agent)\n'

# El corazón del preset: si mañana alguien mete otro grupo aquí, esto falla.
assert_eq "$(dests symlinks_claude)" "$(dests phase_symlinks_agent)" \
    "enlaza exactamente lo mismo que symlinks_claude"

AGENTE="$(run_group phase_symlinks_agent)"
for prohibido in .zshrc .tmux.conf .gitconfig starship.toml .vimrc colors.conf \
                 rtk wezterm iTerm2 direnv nvim; do
    assert_not_contains "$AGENTE" "$prohibido" \
        "no toca nada de $prohibido"
done

printf '\nphase_symlinks (preset completo)\n'

# Guarda de grupo huérfano. La lista se DERIVA del archivo, no se escribe a
# mano: un grupo nuevo que nadie llame aparece aquí solo.
GRUPOS=$(grep -oE '^symlinks_[a-z0-9]+\(\)' "$LIB_DIR/symlinks.sh" | tr -d '()')
CUERPO=$(declare -f phase_symlinks)
for g in $GRUPOS; do
    assert_contains "$CUERPO" "$g" "phase_symlinks llama a $g"
done

# Y la salida completa tiene que ser exactamente la suma de los grupos en orden.
# Cubre lo que la comprobación de arriba no ve: que ninguno se llame dos veces y
# que el orden sea el declarado (el orden es el que ve el usuario en pantalla).
esperado_completo() {
    safe_mkdir "$HOME/.config"
    symlinks_shell
    symlinks_ssh
    symlinks_claude
    symlinks_rtk
    symlinks_wezterm
    symlinks_iterm2
    symlinks_direnv
    symlinks_nvim
}
assert_eq "$(run_group esperado_completo)" "$(run_group phase_symlinks)" \
    "su salida es la concatenación de los grupos, en orden"

# Y sigue enlazando lo interactivo: la variante de agente no debe filtrarse al
# preset completo.
assert_contains "$(dests phase_symlinks)" "$FAKE_HOME/.zshrc" \
    "el preset completo sigue enlazando ~/.zshrc"

printf '\nsafe_link\n'

assert_contains "$(safe_link "$DOTFILES_DIR/no-existe-jamas" "$FAKE_HOME/x" 2>&1)" \
    "Fuente no encontrada" \
    "avisa cuando la fuente no existe"

assert_eq "" "$(dests safe_link "$DOTFILES_DIR/no-existe-jamas" "$FAKE_HOME/x")" \
    "y no intenta enlazar nada"

# La suite entera ha corrido ya: si algo hubiera escrito, estaría aquí.
assert_eq "" "$(find "$FAKE_HOME" -mindepth 1 2>/dev/null)" \
    "en dry-run no se creó nada en disco"

printf '\n%d/%d tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ] || exit 1
