#!/usr/bin/env bash
# Tests de scripts/changelog.sh — sin red, sin tocar el repo real.
# Ejecutar: bash scripts/changelog.test.sh
#
# Cada test monta un repo de git desechable en un temporal, con su propio
# «origin» bare. Nada de esto toca ~/dotfiles ni consulta a GitHub.

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

assert_no_contains() {
    local needle="$1" haystack="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "$haystack" in
        *"$needle"*)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            printf '  ✗ %s\n' "$name"
            printf '      no debía aparecer «%s» en la salida\n' "$needle" ;;
        *)
            printf '  ✓ %s\n' "$name" ;;
    esac
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

SCRIPT="$(cd "$(dirname "$0")" && pwd)/changelog.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# git sin la configuración del usuario: ni hooks heredados, ni firma, ni
# nombre de rama por defecto distinto de main.
g() { git -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"; }

commit_vacio() {
    g commit --allow-empty -q -m "$1"
}

# monta_repo <dir> — repo con origin bare donde:
#   - origin/main tiene una feature YA mergeada («fix(zshrc): fijar fzf»)
#   - la rama main LOCAL se queda atrás, en el commit inicial
#   - HEAD está en una rama nueva con su propio commit
# Es el incidente real de la PR #37: `git fetch` actualiza origin/main pero
# no main, y el rango main..HEAD acaba incluyendo trabajo ajeno.
monta_repo() {
    local dir="$1"
    mkdir -p "$dir/origin.git" "$dir/clon"
    g init -q --bare --initial-branch=main "$dir/origin.git"

    cd "$dir/clon" || return 1
    g init -q --initial-branch=main
    g config user.email t@t.t
    g config user.name Test
    g remote add origin "$dir/origin.git"

    commit_vacio 'chore(repo): commit inicial'
    local inicial
    inicial="$(g rev-parse HEAD)"

    # Feature ajena, mergeada a main y publicada.
    g switch -q -c fix/fzf-pin
    commit_vacio 'fix(zshrc): fijar fzf en 0.68'
    g switch -q main
    g merge -q --no-ff -m 'Merge pull request #36 from kr0nicas/fix/fzf-pin' fix/fzf-pin
    g push -q origin main

    # El main LOCAL se queda rancio: apunta al commit inicial, mientras
    # origin/main ya tiene el merge. Es justo lo que deja un `git fetch`.
    g update-ref refs/heads/main "$inicial"

    # Trabajo en curso, ramificado de lo que de verdad hay publicado.
    g switch -q -c feat/web-escaparate origin/main
    commit_vacio 'feat(web): escaparate en next.js'
}

printf '\nbase_ref: paridad entre local y CI\n'

REPO_A="$WORK/a"
monta_repo "$REPO_A" >/dev/null

bash "$SCRIPT" >/dev/null 2>&1
SALIDA_LOCAL="$(cat CHANGELOG.md)"

# La sección de la rama en curso solo puede listar el trabajo de la rama.
# Con el main local rancio, el commit del pin de fzf —que ya está en
# origin/main— se colaba aquí como si fuera trabajo nuevo.
SECCION_RAMA="$(printf '%s\n' "$SALIDA_LOCAL" | sed -n '/· feat\/web-escaparate/,/^## /p')"
assert_contains 'escaparate en next.js' "$SECCION_RAMA" \
    "la sección de la rama lista el commit de la rama"
assert_no_contains 'fijar fzf' "$SECCION_RAMA" \
    "la sección de la rama NO lista un commit que ya está en origin/main"

# El mismo repo sin rama main local: es lo que ve actions/checkout en CI.
# Si las dos salidas difieren, el check pasa en local y falla en CI.
g branch -q -D main
bash "$SCRIPT" >/dev/null 2>&1
SALIDA_CI="$(cat CHANGELOG.md)"
assert_eq "$SALIDA_CI" "$SALIDA_LOCAL" \
    "la salida es idéntica con y sin rama main local"

printf '\nbase_ref: repo sin remoto\n'

REPO_B="$WORK/b"
mkdir -p "$REPO_B"
cd "$REPO_B" || exit 1
g init -q --initial-branch=main
g config user.email t@t.t
g config user.name Test
commit_vacio 'chore(repo): commit inicial'
g switch -q -c feat/algo
commit_vacio 'feat(zshrc): algo nuevo'

# Sin origin no hay origin/main: tiene que caer a la rama local y seguir
# funcionando, no reventar buscando una ref que no existe.
bash "$SCRIPT" >/dev/null 2>&1
RC_SIN_REMOTO=$?
SALIDA_SIN_REMOTO="$(cat CHANGELOG.md 2>/dev/null || true)"
assert_eq "0" "$RC_SIN_REMOTO" "sale 0 en un repo sin remoto"
assert_contains 'algo nuevo' "$SALIDA_SIN_REMOTO" \
    "sin remoto, la rama se compara contra el main local"

printf '\n'
if [ "$TESTS_FAILED" -eq 0 ]; then
    printf '%s tests, todos OK\n\n' "$TESTS_RUN"
    exit 0
fi
printf '%s tests, %s fallaron\n\n' "$TESTS_RUN" "$TESTS_FAILED"
exit 1
