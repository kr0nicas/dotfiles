#!/usr/bin/env bash
# Genera CHANGELOG.md desde el historial de git.
#
# ARCHIVO GENERADO: no edites CHANGELOG.md a mano, se sobrescribe.
#
# Uso:
#   scripts/changelog.sh            regenera CHANGELOG.md
#   scripts/changelog.sh --check    no escribe; sale 1 si el de disco difiere
#
# La unidad de agrupación es la feature, y se resuelve de dos formas según
# dónde esté (ver el spec): merge commits si ya está en main, main..HEAD si
# sigue en la rama. Ambos caminos tienen que producir el mismo encabezado,
# o el archivo cambiaría solo por mergear.
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-main}"
OUT="CHANGELOG.md"

# titulo_de_tipo <tipo> -> nombre de sección. case, no array asociativo:
# /bin/bash en macOS es 3.2 y no los soporta.
titulo_de_tipo() {
    case "$1" in
        feat)     printf 'Features' ;;
        fix)      printf 'Fixes' ;;
        perf)     printf 'Rendimiento' ;;
        refactor) printf 'Refactors' ;;
        docs)     printf 'Documentación' ;;
        test)     printf 'Tests' ;;
        ci|build) printf 'CI' ;;
        chore)    printf 'Mantenimiento' ;;
        revert)   printf 'Reverts' ;;
        *)        printf 'Otros' ;;
    esac
}

# solo_changelog <sha> -> 0 si el commit toca únicamente CHANGELOG.md
#
# Estos commits se excluyen del listado, y no es cosmético: sin la exclusión el
# archivo es INSATISFACIBLE. El commit que regenera el CHANGELOG entraría en su
# propio listado con su propio SHA, así que al regenerar volvería a diferir;
# amendarlo cambia el SHA y vuelve a diferir. Regresión infinita, y el job
# changelog-drift no podría pasar jamás. Verificado empíricamente.
solo_changelog() {
    local tocados
    tocados="$(git show --name-only --format= "$1" 2>/dev/null | sed '/^$/d')"
    [ "$tocados" = "CHANGELOG.md" ]
}

# emite_rango <rango> — lista los commits del rango agrupados por tipo.
emite_rango() {
    local rango="$1" tipo linea shas sha excluidos entradas matched=''

    # Los commits que solo tocan CHANGELOG.md se descartan antes de agrupar.
    shas="$(git log "$rango" --no-merges --reverse --format='%H' 2>/dev/null)"
    excluidos=''
    for sha in $shas; do
        if solo_changelog "$sha"; then
            excluidos="$excluidos $sha"
        fi
    done

    # (sha completo, sha corto, asunto) de todo el rango, ya sin los
    # commits que solo tocan CHANGELOG.md. Se calcula una sola vez y se
    # reutiliza por tipo, en vez de repetir el filtrado por exclusión en
    # cada vuelta del for de abajo.
    entradas="$(git log "$rango" --no-merges --reverse \
                    --format='%H%x09%h%x09%s' 2>/dev/null \
                | while IFS="$(printf '\t')" read -r full corto asunto; do
                      case " $excluidos " in
                          *" $full "*) continue ;;
                      esac
                      printf '%s\t%s\t%s\n' "$full" "$corto" "$asunto"
                  done)"

    for tipo in feat fix perf refactor docs test ci build chore revert; do
        linea="$(printf '%s\n' "$entradas" \
                 | grep -E "$(printf '\t%s(\\(|!|:)' "$tipo")" || true)"
        [ -n "$linea" ] || continue

        # Se registran los sha completos que ya casaron con un tipo, para
        # el barrido de "Otros" de más abajo.
        matched="$matched $(printf '%s\n' "$linea" | cut -f1 | tr '\n' ' ')"

        printf '\n### %s\n\n' "$(titulo_de_tipo "$tipo")"
        printf '%s\n' "$linea" | while IFS=$'\t' read -r full corto asunto; do
            # «feat(iterm2): perfil» -> «**iterm2**: perfil»
            case "$asunto" in
                *\(*\)*)
                    ambito="$(printf '%s' "$asunto" | sed -E 's/^[a-z]+\(([^)]+)\).*/\1/')"
                    texto="$(printf '%s' "$asunto" | sed -E 's/^[a-z]+\([^)]+\)!?: //')"
                    printf -- '- **%s**: %s (`%s`)\n' "$ambito" "$texto" "$corto"
                    ;;
                *)
                    texto="$(printf '%s' "$asunto" | sed -E 's/^[a-z]+!?: //')"
                    printf -- '- %s (`%s`)\n' "$texto" "$corto"
                    ;;
            esac
        done
    done

    # Nada puede desaparecer en silencio: cualquier commit del rango que no
    # haya casado con ningún tipo conocido —el `Revert "..."` que genera git
    # es el caso real, pero también cubre un tipo nuevo que aún no esté en
    # la lista de arriba— se emite tal cual bajo Otros, sin intentar
    # extraerle un ámbito a un mensaje que no sigue el formato convencional.
    linea="$(printf '%s\n' "$entradas" | while IFS=$'\t' read -r full corto asunto; do
                  [ -n "$full" ] || continue
                  case " $matched " in
                      *" $full "*) continue ;;
                  esac
                  printf '%s\t%s\n' "$corto" "$asunto"
              done)"
    if [ -n "$linea" ]; then
        printf '\n### Otros\n\n'
        printf '%s\n' "$linea" | while IFS=$'\t' read -r corto asunto; do
            printf -- '- %s (`%s`)\n' "$asunto" "$corto"
        done
    fi
}

# La ref base: main local si existe, si no origin/main. En CI el checkout
# del PR no siempre crea la rama local.
base_ref() {
    if git rev-parse --verify --quiet "$BASE_BRANCH" >/dev/null; then
        printf '%s' "$BASE_BRANCH"
    else
        printf 'origin/%s' "$BASE_BRANCH"
    fi
}

# fecha_de <sha> -> YYYY-MM-DD. date -r es BSD, date -d es GNU.
fecha_de() {
    local ts
    ts="$(git log -1 --format='%ct' "$1")"
    date -u -r "$ts" '+%Y-%m-%d' 2>/dev/null || date -u -d "@$ts" '+%Y-%m-%d'
}

# encabezado_de_merge <sha> -> solo el nombre de rama.
#
# El número de PR queda FUERA a propósito: el encabezado tiene que ser
# idéntico antes y después del merge, y antes del merge no hay número que
# leer sin consultar a la API. Si el texto cambiara al mergear, el archivo
# se desincronizaría solo por integrar, y el check de drift sería inútil.
encabezado_de_merge() {
    git log -1 --format='%s' "$1" \
        | sed -E 's|^Merge pull request #[0-9]+ from [^/]+/(.*)$|\1|; s|^Merge branch .(.*).$|\1|'
}

generar() {
    local base sha ts padres fecha asunto rama tip
    base="$(base_ref)"

    printf '# Changelog\n\n'
    printf 'Generado por `scripts/changelog.sh` desde el historial de git.\n'
    printf 'No lo edites a mano: el CI regenera y compara.\n'

    # 1. Feature todavía en la rama, si la hay. Va arriba: es lo más nuevo.
    rama="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$rama" != "$BASE_BRANCH" ] && [ "$rama" != "HEAD" ]; then
        if [ "$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)" -gt 0 ]; then
            # La fecha sale del último commit del rango, no de hoy: si saliera
            # de `date` el archivo cambiaría solo por pasar la medianoche.
            printf '\n## %s · %s\n' "$(fecha_de HEAD)" "$rama"
            emite_rango "$base..HEAD"
        fi
    fi

    # 2. Features ya integradas: main por --first-parent, de la más nueva a la
    #    más vieja.
    git log --first-parent --format='%H %ct %P' "$base" 2>/dev/null \
    | while read -r sha ts padres; do
        case "$padres" in
            *\ *)   # dos o más padres: es un merge, o sea una feature
                # La fecha sale de la punta de la rama (sha^2), no del merge,
                # para que coincida con la que se emitió antes de mergear.
                tip="$(git rev-parse "$sha^2")"
                printf '\n## %s · %s\n' "$(fecha_de "$tip")" "$(encabezado_de_merge "$sha")"
                emite_rango "$sha^1..$sha^2"
                ;;
            *)      # commit suelto en main (historial anterior al arnés)
                fecha="$(fecha_de "$sha")"
                asunto="$(git log -1 --format='%s' "$sha")"
                printf '\n## %s · %s\n\n' "$fecha" "$asunto"
                printf -- '- (`%s`)\n' "$(git log -1 --format='%h' "$sha")"
                ;;
        esac
    done
}

if [ "${1:-}" = "--check" ]; then
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    generar > "$tmp"
    if ! diff -q "$tmp" "$OUT" >/dev/null 2>&1; then
        printf 'CHANGELOG.md está desactualizado. Corre: scripts/changelog.sh\n' >&2
        diff -u "$OUT" "$tmp" >&2 || true
        exit 1
    fi
    printf 'CHANGELOG.md al día\n'
    exit 0
fi

generar > "$OUT"
printf 'CHANGELOG.md regenerado\n'
