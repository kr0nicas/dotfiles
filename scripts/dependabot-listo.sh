#!/usr/bin/env bash
# Deja una PR de Dependabot lista para mergear: le integra main y le añade el
# commit de CHANGELOG que Dependabot nunca genera.
#
# Uso:
#   scripts/dependabot-listo.sh <número-de-PR>
#
# Por qué existe: el job «CHANGELOG al día» exige que cada rama traiga su
# CHANGELOG.md regenerado, y Dependabot no corre scripts/changelog.sh, así que
# sus PRs nacen en rojo y se quedan bloqueadas. Saltarse el job para ellas no
# sirve: el mismo check corre en cada push a main, y main quedaría en rojo
# después de cada merge hasta que otra PR regenerase el archivo.
#
# Trabaja en un worktree temporal: no toca el árbol de trabajo ni la rama en la
# que estés. No fuerza el push —solo añade commits encima de la rama— y no
# mergea: eso se hace con el CI en verde.
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-main}"

err() {
    printf 'dependabot-listo: %s\n' "$*" >&2
    exit 1
}

[ "$#" -eq 1 ] || err "uso: scripts/dependabot-listo.sh <número-de-PR>"
PR="$1"
case "$PR" in
    ''|*[!0-9]*) err "«$PR» no es un número de PR" ;;
esac

command -v gh >/dev/null 2>&1 || err "falta gh (GitHub CLI)"

RAIZ="$(git rev-parse --show-toplevel)"
cd "$RAIZ"

# Estado, autor y rama se le preguntan a GitHub, no se deducen del nombre.
DATOS="$(gh pr view "$PR" --json state,author,headRefName \
            --jq '[.state, .author.login, .headRefName] | @tsv')" \
    || err "no se pudo leer la PR #$PR"
IFS=$'\t' read -r ESTADO AUTOR RAMA <<<"$DATOS"

[ "$ESTADO" = "OPEN" ] || err "la PR #$PR no está abierta (estado: $ESTADO)"
# Solo Dependabot: una PR de persona sigue el flujo normal, donde el CHANGELOG
# lo regenera su autor. Aquí se escribiría en una rama ajena sin avisar.
case "$AUTOR" in
    *dependabot*) ;;
    *) err "la PR #$PR es de «$AUTOR», no de Dependabot" ;;
esac
[ -n "$RAMA" ] || err "la PR #$PR no tiene rama de origen"

# changelog.sh necesita una rama con el nombre real —en detached HEAD omite la
# sección de la rama en curso—, así que se crea una local. Si ya existe puede
# tener trabajo sin publicar: no se pisa.
if git show-ref --verify --quiet "refs/heads/$RAMA"; then
    err "ya existe una rama local «$RAMA»; bórrala o publícala antes"
fi

git fetch --quiet origin "$BASE_BRANCH" "$RAMA" \
    || err "no se pudo traer origin/$BASE_BRANCH y origin/$RAMA"

WT="$(mktemp -d)"
limpia() {
    cd "$RAIZ" || return
    git worktree remove --force "$WT" >/dev/null 2>&1 || true
    rm -rf "$WT"
    git branch -q -D "$RAMA" >/dev/null 2>&1 || true
}
trap limpia EXIT

git worktree add -q -b "$RAMA" "$WT" "origin/$RAMA"
cd "$WT"

# 1. Integrar main. Con merge y no con rebase: reescribir la rama obligaría a
#    forzar el push.
if ! git merge -q --no-edit "origin/$BASE_BRANCH" >/dev/null 2>&1; then
    CONFLICTOS="$(git diff --name-only --diff-filter=U)"
    if [ "$CONFLICTOS" != "CHANGELOG.md" ]; then
        git merge --abort >/dev/null 2>&1 || true
        err "conflictos al integrar $BASE_BRANCH que hay que resolver a mano: $(printf '%s' "$CONFLICTOS" | tr '\n' ' ')"
    fi
    # El único conflicto es el archivo generado, y pasa al repetir el script
    # después de que main avance. Se toma el de main; el paso 2 lo regenera.
    git checkout -q --theirs CHANGELOG.md
    git add CHANGELOG.md
    git commit -q --no-edit
fi

# 2. Regenerar el CHANGELOG, en su propio commit.
./scripts/changelog.sh >/dev/null
if ! git diff --quiet -- CHANGELOG.md; then
    git add CHANGELOG.md
    git commit -q -m 'docs(repo): regenerar CHANGELOG'
fi

if [ "$(git rev-parse HEAD)" = "$(git rev-parse "origin/$RAMA")" ]; then
    printf 'La PR #%s ya estaba al día: nada que publicar.\n' "$PR"
    exit 0
fi

# 3. Publicar. Sin --force: todo lo anterior son commits encima de la rama.
git push -q origin "HEAD:refs/heads/$RAMA"

printf 'PR #%s actualizada (%s).\n' "$PR" "$RAMA"
printf 'Cuando el CI esté en verde: gh pr merge %s --merge --delete-branch\n' "$PR"
