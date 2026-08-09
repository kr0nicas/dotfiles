#!/bin/bash

# GitHub Topics Manager - Script para agregar topics a repositorios GitHub
# Uso: ./github-topics-manager.sh <repo-name> "topic1,topic2,topic3"

# -u es deliberado: este script llegó a mandar un topic vacío a la API porque
# un array mal escrito expandía a cero palabras sin quejarse. Con -u eso aborta.
# Obliga a que todo acceso a $1/$2 lleve ${...:-}: son opcionales de verdad.
set -eu

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de ayuda
show_help() {
    echo -e "${BLUE}GitHub Topics Manager${NC}"
    echo ""
    echo "Uso: $0 <repo-name> \"topic1,topic2,topic3\""
    echo ""
    echo "Ejemplos:"
    echo "  $0 ochoajorge-blog-me \"blog,nextjs,typesctipt,mdx,portfolio\""
    echo "  $0 dotfiles \"dotfiles,zsh,linux,macos,cross-platform\""
    echo ""
    echo "Opciones:"
    echo "  -h, --help     Mostrar esta ayuda"
    echo "  -v, --verify   Verificar topics actuales del repo"
    echo "  -l, --list     Listar repos del usuario actual"
    exit 0
}

# Función para verificar topics
verify_topics() {
    local repo=$1
    echo -e "${BLUE}📋 Topics actuales de $repo:${NC}"
    gh api "repos/$(gh api user --jq '.login')/$repo/topics" --jq '.names | join(", ")' || {
        echo -e "${RED}❌ Error obteniendo topics de $repo${NC}"
        return 1
    }
}

# Función para listar repos
list_repos() {
    echo -e "${BLUE}📁 Repositorios del usuario:${NC}"
    gh repo list --limit 100 --json name,visibility --jq '.[] | "\(.name) (\(.visibility))"' | sort
}

# Verificar gh CLI está instalado
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ Error: gh CLI no está instalado${NC}"
        echo "Instala GitHub CLI: https://cli.github.com/"
        exit 1
    fi

    # Verificar autenticación
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ Error: gh CLI no está autenticado${NC}"
        echo "Ejecuta: gh auth login"
        exit 1
    fi
}

# Parsear argumentos
case "${1:-}" in
    -h|--help)
        show_help
        ;;
    -v|--verify)
        if [ -z "${2:-}" ]; then
            echo -e "${RED}❌ Error: Se requiere nombre del repo${NC}"
            echo "Uso: $0 -v <repo-name>"
            exit 1
        fi
        check_gh_cli
        verify_topics "$2"
        exit 0
        ;;
    -l|--list)
        check_gh_cli
        list_repos
        exit 0
        ;;
esac

# Verificar argumentos principales
if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo -e "${RED}❌ Error: Se requieren dos argumentos${NC}"
    echo ""
    echo "Uso: $0 <repo-name> \"topic1,topic2,topic3\""
    echo ""
    echo "Para ver ayuda: $0 --help"
    exit 1
fi

REPO_NAME="$1"
TOPICS="$2"

# Verificar gh CLI
check_gh_cli

# Obtener nombre de usuario
USERNAME=$(gh api user --jq '.login')

# Verificar que el repo existe
echo -e "${BLUE}🔍 Verificando repositorio $USERNAME/$REPO_NAME...${NC}"
if ! gh api "repos/$USERNAME/$REPO_NAME" &> /dev/null; then
    echo -e "${RED}❌ Error: El repositorio $USERNAME/$REPO_NAME no existe${NC}"
    echo "O no tienes permisos para acceder a él."
    exit 1
fi

# Parsear topics (separar por comas)
IFS=',' read -ra TOPIC_ARRAY <<< "$TOPICS"

# Validar topics (GitHub tiene restricciones)
VALID_TOPICS=()
for topic in "${TOPIC_ARRAY[@]}"; do
    # Limpiar espacios y convertir a minúsculas
    clean_topic=$(echo "$topic" | xargs | tr '[:upper:]' '[:lower:]')

    # Validar longitud (máximo 35 caracteres)
    if [ ${#clean_topic} -gt 35 ]; then
        echo -e "${YELLOW}⚠️  Warning: Topic '$clean_topic' excede 35 caracteres, omitiendo${NC}"
        continue
    fi

    # Validar caracteres (solo letras, números, guiones)
    if [[ "$clean_topic" =~ ^[a-z0-9-]+$ ]]; then
        VALID_TOPICS+=("$clean_topic")
    else
        echo -e "${YELLOW}⚠️  Warning: Topic '$clean_topic' contiene caracteres inválidos, omitiendo${NC}"
        continue
    fi
done

# Verificar que haya topics válidos
if [ ${#VALID_TOPICS[@]} -eq 0 ]; then
    echo -e "${RED}❌ Error: No hay topics válidos para agregar${NC}"
    exit 1
fi

# Mostrar topics que se van a agregar
echo -e "${GREEN}✅ Topics válidos (${#VALID_TOPICS[@]}):${NC}"
printf "   - %s\n" "${VALID_TOPICS[@]}"

# Crear JSON con topics
TOPICS_JSON=$(printf '%s\n' "${VALID_TOPICS[@]}" | jq -R . | jq -s . | jq -c '{names: .}')

# Actualizar topics via GitHub API
echo -e "${BLUE}🏷️ Actualizando topics en $USERNAME/$REPO_NAME...${NC}"

# La asignación va dentro del `if`, no antes: `RESPONSE=$(...)` en su propia
# línea aborta el script por `set -e` en cuanto gh falla, así que la rama de
# error de abajo era inalcanzable. Dentro de la condición, `set -e` no aplica.
if RESPONSE=$(gh api "repos/$USERNAME/$REPO_NAME/topics" \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  --input - <<< "$TOPICS_JSON" \
  --jq '.names | join(", ")' 2>&1); then
    echo -e "${GREEN}✅ Topics actualizados exitosamente${NC}"
    echo -e "${BLUE}📋 Nuevos topics: $RESPONSE${NC}"

    # Mostrar URL del repo
    echo ""
    echo -e "${BLUE}🔗 Repositorio: https://github.com/$USERNAME/$REPO_NAME${NC}"
else
    echo -e "${RED}❌ Error actualizando topics${NC}"
    echo "$RESPONSE"
    exit 1
fi

exit 0
