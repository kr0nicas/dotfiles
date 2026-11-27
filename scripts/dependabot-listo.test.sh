#!/usr/bin/env bash
# Tests de scripts/dependabot-listo.sh — sin red, sin tocar el repo real.
# Ejecutar: bash scripts/dependabot-listo.test.sh
#
# Cada test monta un repo de git desechable en un temporal, con su propio
# «origin» bare, y un `gh` falso en el PATH que contesta lo que diga
# GH_STUB_OUT. Nada de esto toca ~/dotfiles ni consulta a GitHub.

# Sin el entorno de git del llamador. Si esta suite corre desde un hook en un
# worktree enlazado hereda GIT_DIR, y cada `git init` de abajo dejaría de crear
# un repo desechable para reconfigurar el repo real. pre-push ya lo limpia;
# esto cubre cualquier otra forma de llegar aquí con GIT_DIR puesto.
while read -r _var_git; do
    unset "$_var_git"
done < <(git rev-parse --local-env-vars 2>/dev/null)

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

assert_ne() {
    local no_esperado="$1" actual="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$no_esperado" != "$actual" ]; then
        printf '  ✓ %s\n' "$name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  ✗ %s\n' "$name"
        printf '      no debía ser «%s»\n' "$no_esperado"
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

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/dependabot-listo.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# gh falso: el script solo le pide una línea «estado<TAB>autor<TAB>rama».
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
[ -n "${GH_STUB_OUT:-}" ] || exit 1
printf '%s\n' "$GH_STUB_OUT"
STUB
chmod +x "$WORK/bin/gh"
PATH="$WORK/bin:$PATH"

RAMA_DEP='dependabot/npm_and_yarn/web/web-abc123'

# gh_dice <estado> <autor> [rama] — fija la respuesta del gh falso.
gh_dice() {
    GH_STUB_OUT="$(printf '%s\t%s\t%s' "$1" "$2" "${3:-$RAMA_DEP}")"
    export GH_STUB_OUT
}

# feature_en_main <rama> <archivo> <asunto> — una feature con el flujo real del
# repo: commit de trabajo, commit de CHANGELOG aparte, merge --no-ff y push.
feature_en_main() {
    git switch -q -c "$1" main
    printf '%s\n' "$3" > "$2"
    git add "$2"
    git commit -q -m "$3"
    ./scripts/changelog.sh >/dev/null
    git add CHANGELOG.md
    git commit -q -m 'docs(repo): regenerar CHANGELOG'
    git switch -q main
    git merge -q --no-ff -m "Merge pull request #1 from t/$1" "$1"
    git branch -q -D "$1"
    git push -q origin main
}

# monta_repo <dir> — deja el cwd en un clon donde:
#   - origin/main trae changelog.sh y un CHANGELOG.md al día
#   - origin tiene una rama de Dependabot nacida de ese main, SIN commit de
#     CHANGELOG (Dependabot no lo genera) y sin copia local
#   - main avanzó después con otra feature: la rama quedó atrás
monta_repo() {
    local dir="$1"
    mkdir -p "$dir/origin.git" "$dir/clon/scripts"
    git init -q --bare --initial-branch=main "$dir/origin.git"

    cd "$dir/clon" || return 1
    git init -q --initial-branch=main
    # Config local y no -c: el script bajo prueba llama a git a secas, y los
    # worktrees que crea comparten este config.
    git config user.email t@t.t
    git config user.name Test
    git config commit.gpgsign false
    git config core.hooksPath /dev/null
    git remote add origin "$dir/origin.git"

    cp "$AQUI/changelog.sh" scripts/changelog.sh
    printf 'v1\n' > deps.txt
    git add scripts/changelog.sh deps.txt
    git commit -q -m 'chore(repo): commit inicial'
    ./scripts/changelog.sh >/dev/null
    git add CHANGELOG.md
    git commit -q -m 'docs(repo): regenerar CHANGELOG'
    git push -q origin main

    git switch -q -c "$RAMA_DEP"
    printf 'v2\n' > deps.txt
    git commit -q -am 'chore(deps): bump algo from 1 to 2'
    git push -q origin "$RAMA_DEP"
    git switch -q main
    git branch -q -D "$RAMA_DEP"

    feature_en_main fix/fzf-pin fzf.txt 'fix(zshrc): fijar fzf'
}

# changelog_al_dia — 0 si la rama de Dependabot publicada pasa --check.
changelog_al_dia() {
    local rc
    git fetch -q origin
    git switch -q -c "$RAMA_DEP" "origin/$RAMA_DEP"
    ./scripts/changelog.sh --check >/dev/null 2>&1
    rc=$?
    git switch -q main
    git branch -q -D "$RAMA_DEP"
    return "$rc"
}

sha_remoto() { git ls-remote origin "refs/heads/$RAMA_DEP" | cut -f1; }

# ══ Camino feliz ══════════════════════════════════════════════════════════════
printf '\n  PR de Dependabot atrasada\n'
monta_repo "$WORK/a" || exit 1
gh_dice OPEN app/dependabot
SHA_ANTES="$(sha_remoto)"
printf 'a medias\n' > sin-commitear.txt

SALIDA="$(bash "$SCRIPT" 58 2>&1)"
assert_eq "0" "$?" "sale 0"
assert_contains 'gh pr merge 58 --merge --delete-branch' "$SALIDA" \
    "dice cómo mergear, con el número de la PR"

git fetch -q origin
assert_ne "$SHA_ANTES" "$(sha_remoto)" "publica commits en la rama"
git merge-base --is-ancestor "$SHA_ANTES" "origin/$RAMA_DEP"
assert_eq "0" "$?" "sin reescribir: la punta anterior sigue en la historia"
git merge-base --is-ancestor origin/main "origin/$RAMA_DEP"
assert_eq "0" "$?" "la rama contiene el main actual"
assert_eq "CHANGELOG.md" \
    "$(git show --name-only --format= "origin/$RAMA_DEP" | sed '/^$/d')" \
    "el último commit toca solo CHANGELOG.md"
changelog_al_dia
assert_eq "0" "$?" "changelog.sh --check pasa en la rama publicada"

assert_eq "main" "$(git rev-parse --abbrev-ref HEAD)" "no cambia la rama en la que estabas"
assert_eq "a medias" "$(cat sin-commitear.txt)" "no toca el árbol de trabajo"
assert_eq "" "$(git branch --list "$RAMA_DEP")" "no deja la rama local"
assert_eq "1" "$(git worktree list | wc -l | tr -d ' ')" "no deja el worktree temporal"

# ══ Repetir ═══════════════════════════════════════════════════════════════════
printf '\n  Repetir sobre una PR ya lista\n'
SHA_LISTA="$(sha_remoto)"
SALIDA="$(bash "$SCRIPT" 58 2>&1)"
assert_eq "0" "$?" "sale 0"
assert_eq "$SHA_LISTA" "$(sha_remoto)" "no publica nada nuevo"
assert_contains 'ya estaba al día' "$SALIDA" "lo dice"

# main avanza con la PR ya preparada: ahora los dos lados tocaron CHANGELOG.md
# y el merge choca en el archivo generado. Es el caso de mergear dos PRs de
# Dependabot seguidas.
printf '\n  main avanza después de prepararla\n'
feature_en_main fix/otra otra.txt 'fix(zshrc): otra cosa'
SALIDA="$(bash "$SCRIPT" 58 2>&1)"
assert_eq "0" "$?" "resuelve solo el conflicto de CHANGELOG.md"
changelog_al_dia
assert_eq "0" "$?" "y la rama vuelve a pasar --check"

# ══ Rechazos ══════════════════════════════════════════════════════════════════
printf '\n  Lo que rechaza\n'
SHA_ANTES="$(sha_remoto)"

gh_dice OPEN kr0nicas
SALIDA="$(bash "$SCRIPT" 58 2>&1)"
assert_ne "0" "$?" "una PR que no es de Dependabot"
assert_contains 'no de Dependabot' "$SALIDA" "y explica por qué"

gh_dice MERGED app/dependabot
bash "$SCRIPT" 58 >/dev/null 2>&1
assert_ne "0" "$?" "una PR que no está abierta"

gh_dice OPEN app/dependabot
bash "$SCRIPT" abc >/dev/null 2>&1
assert_ne "0" "$?" "un argumento que no es un número"
bash "$SCRIPT" >/dev/null 2>&1
assert_ne "0" "$?" "que no le pasen argumento"

git branch -q "$RAMA_DEP" main
bash "$SCRIPT" 58 >/dev/null 2>&1
assert_ne "0" "$?" "una rama local con el mismo nombre"
assert_eq "$(git rev-parse main)" "$(git rev-parse "$RAMA_DEP")" \
    "y no la borra: no la creó el script"
git branch -q -D "$RAMA_DEP"

assert_eq "$SHA_ANTES" "$(sha_remoto)" "ningún rechazo publicó nada"

# ══ Conflicto real ════════════════════════════════════════════════════════════
printf '\n  Conflicto fuera de CHANGELOG.md\n'
monta_repo "$WORK/b" || exit 1
gh_dice OPEN app/dependabot
# main cambia el mismo archivo que tocó Dependabot.
git switch -q -c fix/deps main
printf 'v3\n' > deps.txt
git commit -q -am 'fix(zshrc): pisar deps'
git switch -q main
git merge -q --no-ff -m 'Merge pull request #2 from t/fix/deps' fix/deps
git branch -q -D fix/deps
git push -q origin main
SHA_ANTES="$(sha_remoto)"

SALIDA="$(bash "$SCRIPT" 58 2>&1)"
assert_ne "0" "$?" "sale distinto de 0"
assert_contains 'deps.txt' "$SALIDA" "nombra el archivo en conflicto"
assert_eq "$SHA_ANTES" "$(sha_remoto)" "no publica nada"
assert_eq "" "$(git branch --list "$RAMA_DEP")" "no deja la rama local"
assert_eq "1" "$(git worktree list | wc -l | tr -d ' ')" "no deja el worktree temporal"

printf '\n'
if [ "$TESTS_FAILED" -eq 0 ]; then
    printf '%s tests, todos OK\n\n' "$TESTS_RUN"
    exit 0
fi
printf '%s tests, %s fallaron\n\n' "$TESTS_RUN" "$TESTS_FAILED"
exit 1
