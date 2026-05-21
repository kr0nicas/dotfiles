#!/usr/bin/env bash
# Claude Code statusLine — modelo + workspace + tokens
# Cross-platform: funciona en Linux/WSL y macOS

# Lee JSON desde stdin (Claude lo pasa automáticamente)
INPUT=$(cat)

# Extraer campos del JSON de contexto
MODEL=$(echo "$INPUT" | jq -r '.model // "sonnet"' 2>/dev/null | sed 's/claude-//' | sed 's/-[0-9]*-[0-9]*//' | tr '[:lower:]' '[:upper:]')
TOKENS_IN=$(echo "$INPUT" | jq -r '.session_tokens_in // 0' 2>/dev/null)
TOKENS_OUT=$(echo "$INPUT" | jq -r '.session_tokens_out // 0' 2>/dev/null)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)

# Formatear workspace (mostrar últimos 2 segmentos del path)
if [[ -n "$CWD" ]]; then
  WORKSPACE=$(echo "$CWD" | awk -F'/' '{
    n=NF
    if (n >= 2) print $(n-1)"/"$n
    else print $n
  }')
else
  WORKSPACE=$(basename "$PWD")
fi

# Formatear tokens (k = miles)
format_tokens() {
  local t=$1
  if [[ $t -ge 1000 ]]; then
    echo "$(( t / 1000 ))k"
  else
    echo "${t}"
  fi
}

T_IN=$(format_tokens "$TOKENS_IN")
T_OUT=$(format_tokens "$TOKENS_OUT")

# Output final — Claude Code lo muestra en el statusLine
echo "🤖 ${MODEL:-SONNET}  📁 ${WORKSPACE}  ↑${T_IN} ↓${T_OUT}"
