# 🏷️ GitHub Topics Manager

Script de bash para gestionar topics en repositorios GitHub usando la API y GitHub CLI.

## 📋 Características

- ✅ Agregar topics a repositorios GitHub
- ✅ Validación automática de topics (longitud, caracteres)
- ✅ Verificación de topics actuales
- ✅ Listado de repositorios del usuario
- ✅ Colores y manejo de errores
- ✅ Compatibilidad con repos públicos y privados

## 🚀 Instalación

El script ya está incluido en este repo en `scripts/github-topics-manager.sh`.

### Requisitos

1. **GitHub CLI (gh)** instalado:
   ```bash
   # macOS
   brew install gh

   # Linux
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   ```

2. **Autenticación con GitHub**:
   ```bash
   gh auth login
   ```

## 📖 Uso

### Básico - Agregar Topics

```bash
./scripts/github-topics-manager.sh <repo-name> "topic1,topic2,topic3"
```

**Ejemplos**:
```bash
./scripts/github-topics-manager.sh ochoajorge-blog-me "blog,nextjs,typesctipt,mdx,portfolio"
./scripts/github-topics-manager.sh dotfiles "dotfiles,zsh,linux,macos,cross-platform"
./scripts/github-topics-manager.sh kelova-app "go,python,typesctipt,application,docker"
```

### Verificar Topics Actuales

```bash
./scripts/github-topics-manager.sh --verify <repo-name>
```

**Ejemplo**:
```bash
./scripts/github-topics-manager.sh --verify ochoajorge-blog-me
```

### Listar Repositorios

```bash
./scripts/github-topics-manager.sh --list
```

### Ayuda

```bash
./scripts/github-topics-manager.sh --help
# o
./scripts/github-topics-manager.sh -h
```

## ⚙️ Validación de Topics

El script valida automáticamente los topics antes de agregarlos:

### ✅ Reglas de Validación

1. **Longitud**: Máximo 35 caracteres por topic
2. **Caracteres**: Solo letras, números y guiones (`-`)
3. **Caso**: Convierte automáticamente a minúsculas
4. **Espacios**: Elimina espacios en blanco extra

### ⚠️ Ejemplos de Topics Inválidos

| Topic | Razón |
|-------|-------|
| `Topic Muy Largo Con Más De 35 Caracteres` | Excede 35 caracteres |
| `invalid_topic!` | Carácter inválido `!` |
| `Topic Con Espacios` | Debe usar guiones `-` |

### ✅ Ejemplos de Topics Válidos

| Topic | Válido |
|-------|--------|
| `typescript` | ✅ Sí |
| `nextjs` | ✅ Sí |
| `content-management` | ✅ Sí |
| `cross-platform` | ✅ Sí |

## 📊 Topics Sugeridos por Categoría

### 🎨 Desarrollo Web
- `nextjs`, `react`, `typescript`, `javascript`, `frontend`
- `tailwind`, `css`, `html`, `responsive-design`

### 🔧 Backend & APIs
- `go`, `python`, `fastapi`, `rest-api`, `api`
- `docker`, `kubernetes`, `microservices`

### 🗄️ Databases & Data
- `postgresql`, `mysql`, `mongodb`, `redis`
- `database`, `data-engineering`, `etl`

### 🤖 Inteligencia Artificial
- `machine-learning`, `ai`, `nlp`, `llm`
- `tensorflow`, `pytorch`, `agents`, `automation`

### 📱 Mobile
- `react-native`, `flutter`, `mobile`, `ios`, `android`

### 🛠️ DevOps & Infraestructura
- `devops`, `ci-cd`, `github-actions`, `terraform`
- `aws`, `gcp`, `azure`, `cloud`

### 🎓 Educación & Tutoriales
- `tutorial`, `learning`, `education`, `examples`
- `documentation`, `guide`

### 🎯 Configuración & Dotfiles
- `dotfiles`, `zsh`, `linux`, `macos`
- `configuration`, `productivity`, `terminal`

## 🔧 Ejemplos de Uso Completos

### Configurar Blog Personal

```bash
./scripts/github-topics-manager.sh ochoajorge-blog-me "blog,nextjs,typesctipt,mdx,portfolio,content-management"
```

### Configurar Dotfiles Cross-Platform

```bash
./scripts/github-topics-manager.sh dotfiles "dotfiles,zsh,linux,macos,cross-platform,configuration,terminal"
```

### Configurar Aplicación Full-Stack

```bash
./scripts/github-topics-manager.sh mi-app "go,python,typesctipt,rest-api,docker,development,application"
```

### Configurar Proyecto de Machine Learning

```bash
./scripts/github-topics-manager.sh ml-project "machine-learning,python,tensorflow,data-science,ai,automation"
```

## 📝 Workflow Sugerido

### 1. Verificar Topics Actuales

```bash
./scripts/github-topics-manager.sh --verify mi-repo
```

### 2. Listar Repos Disponibles

```bash
./scripts/github-topics-manager.sh --list
```

### 3. Agregar o Actualizar Topics

```bash
./scripts/github-topics-manager.sh mi-repo "topic1,topic2,topic3"
```

### 4. Verificar el Resultado

```bash
./scripts/github-topips-manager.sh --verify mi-repo
# o visita https://github.com/tu-usuario/mi-repo
```

## 🛡️ Seguridad y Permisos

El script utiliza GitHub CLI que debe estar autenticado:

- **Repos Públicos**: Solo requiere permisos de lectura y escritura de repos
- **Repos Privados**: Requiere permisos adicionales de acceso a repos privados

### Rotación de Token

Si cambias de token GitHub, simplemente vuelve a autenticarte:

```bash
gh auth logout
gh auth login
```

## 🐛 Troubleshooting

### Error: "gh CLI no está instalado"

```bash
# macOS
brew install gh

# Linux
sudo apt install gh
```

### Error: "gh CLI no está autenticado"

```bash
gh auth login
```

### Error: "Topic excede 35 caracteres"

Acorta el topic o usa abreviaciones:
- ❌ `machine-learning-and-ai-with-tensorflow` (muy largo)
- ✅ `machine-learning` ✅ `ai` ✅ `tensorflow`

### Error: "Topic contiene caracteres inválidos"

Usa solo letras, números y guiones:
- ❌ `javascript!`
- ✅ `javascript`

## 📚 Recursos

- [GitHub Topics Documentation](https://docs.github.com/en/articles/about-topics)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [GitHub REST API - Repositories](https://docs.github.com/en/rest/repos/repos#replace-all-repository-topics)

## 🤝 Contribuciones

Si encuentras bugs o tienes sugerencias, por favor abre un issue en este repositorio.

## 📄 Licencia

Este script es parte de los dotfiles de Jorge Ochoa y está disponible bajo los mismos términos que el repositorio principal.

---

**Creado por:** Jorge Ochoa (@kr0nicas)  
**Fecha:** 2 de junio de 2026  
**Versión:** 1.0.0
