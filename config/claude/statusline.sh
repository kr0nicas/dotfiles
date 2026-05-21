#!/usr/bin/env bash
# Statusline para Claude Code. Lee JSON por stdin y muestra:
#   📁 cwd  🌿 branch  🤖 modelo  💰 $coste  ⏱ duración  ⚠ context
# Catppuccin Mocha. Requiere jq.

set -u

input=$(cat)

if ! command -v jq >/dev/null 2>&1; then
    printf '%s' "$(pwd | sed "s|^$HOME|~|")"
    exit 0
fi

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "?"')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // 0')
dur_ms=$(printf '%s' "$input" | jq -r '.cost.total_duration_ms // 0')
over_ctx=$(printf '%s' "$input" | jq -r '.exceeds_200k_tokens // false')
lines_add=$(printf '%s' "$input" | jq -r '.cost.total_lines_added // 0')
lines_del=$(printf '%s' "$input" | jq -r '.cost.total_lines_removed // 0')

[[ -z "$cwd" ]] && cwd="$PWD"
case "$cwd" in
    "$HOME")   short_cwd="~" ;;
    "$HOME"/*) short_cwd="~${cwd#$HOME}" ;;
    *)         short_cwd="$cwd" ;;
esac

branch=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    if [[ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]]; then
        branch="${branch}*"
    fi
fi

dur_s=$(( dur_ms / 1000 ))
if   (( dur_s < 60 ));   then dur_fmt="${dur_s}s"
elif (( dur_s < 3600 )); then dur_fmt="$(( dur_s / 60 ))m"
else                          dur_fmt="$(( dur_s / 3600 ))h$(( (dur_s % 3600) / 60 ))m"
fi

cost_fmt=$(awk -v c="$cost" 'BEGIN { printf "%.2f", c }')

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

if (( lines_add > 0 || lines_del > 0 )); then
    out+="  ${C_DIM}±${C_GREEN}+${lines_add}${C_DIM}/${C_RED}-${lines_del}${C_RESET}"
fi

[[ "$over_ctx" == "true" ]] && out+="  ${C_RED}⚠ 200k+${C_RESET}"

printf '%b' "$out"
