#!/usr/bin/env bash
# Statusline para Claude Code. Lee JSON por stdin y muestra:
#   📁 cwd  🌿 branch  🤖 modelo  💰 $coste  ⏱ duración  ⚠ context
# Catppuccin Mocha. Requiere jq.
#
# Optimizado (2026-11-12): 1 sola llamada a jq y 1 sola a git
# (antes 7 jq + hasta 4 git + awk ≈ 155 ms por refresco).

set -u

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
    printf '%s' "$(pwd | sed "s|^$HOME|~|")"
    exit 0
fi

# Una sola pasada de jq: campos separados por tabulador.
# El coste se formatea aquí mismo (2 decimales) para no lanzar awk.
IFS=$'\t' read -r cwd model cost_fmt dur_ms over_ctx lines_add lines_del < <(
    printf '%s' "$input" | jq -r '[
        (.workspace.current_dir // .cwd // ""),
        (.model.display_name // .model.id // "?"),
        ((.cost.total_cost_usd // 0) * 100 | round | tostring
            | if length < 3 then ("00" + .)[-3:] else . end
            | .[:-2] + "." + .[-2:]),
        ((.cost.total_duration_ms // 0) | floor | tostring),
        ((.exceeds_200k_tokens // false) | tostring),
        ((.cost.total_lines_added // 0) | tostring),
        ((.cost.total_lines_removed // 0) | tostring)
    ] | @tsv'
)

[[ -z "${cwd:-}" ]] && cwd="$PWD"
case "$cwd" in
    "$HOME")   short_cwd="~" ;;
    # Las comillas internas no son de estilo: sin ellas $HOME se expande como
    # patrón, no como literal, y un HOME con caracteres de glob recortaría mal.
    "$HOME"/*) short_cwd="~${cwd#"$HOME"}" ;;
    *)         short_cwd="$cwd" ;;
esac

# Una sola llamada a git: la cabecera "## rama...upstream" trae la rama y las
# líneas siguientes indican cambios sin commitear. Falla en silencio fuera de un repo.
branch=""
if status=$(git -C "$cwd" status --porcelain --branch --untracked-files=normal 2>/dev/null); then
    head_line=${status%%$'\n'*}
    head_line=${head_line#\#\# }
    case "$head_line" in
        "No commits yet on "*) branch=${head_line#No commits yet on } ;;
        "HEAD (no branch)"*)   branch="(detached)" ;;
        *)                     branch=${head_line%%...*}; branch=${branch%% *} ;;
    esac
    [[ "$status" == *$'\n'* ]] && branch="${branch}*"
fi

dur_s=$(( ${dur_ms:-0} / 1000 ))
if   (( dur_s < 60 ));   then dur_fmt="${dur_s}s"
elif (( dur_s < 3600 )); then dur_fmt="$(( dur_s / 60 ))m"
else                          dur_fmt="$(( dur_s / 3600 ))h$(( (dur_s % 3600) / 60 ))m"
fi

# Catppuccin Mocha (256-color)
C_BLUE='\033[38;5;111m'
C_MAUVE='\033[38;5;183m'
C_GREEN='\033[38;5;151m'
C_YELLOW='\033[38;5;222m'
C_RED='\033[38;5;211m'
C_DIM='\033[38;5;146m'
C_RESET='\033[0m'

out="${C_BLUE}📁 ${short_cwd}${C_RESET}"
[[ -n "$branch" ]] && out+="  ${C_MAUVE}🌿 ${branch}${C_RESET}"
out+="  ${C_GREEN}🤖 ${model}${C_RESET}"
out+="  ${C_YELLOW}💰 \$${cost_fmt}${C_RESET}"
out+="  ${C_DIM}⏱ ${dur_fmt}${C_RESET}"

if (( ${lines_add:-0} > 0 || ${lines_del:-0} > 0 )); then
    out+="  ${C_DIM}±${C_GREEN}+${lines_add}${C_DIM}/${C_RED}-${lines_del}${C_RESET}"
fi

[[ "${over_ctx:-false}" == "true" ]] && out+="  ${C_RED}⚠ 200k+${C_RESET}"

printf '%b' "$out"
