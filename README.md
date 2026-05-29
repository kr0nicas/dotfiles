# Dotfiles SRE 2026 - Jorge Ochoa (kr0nicas)

Entorno de terminal reproducible para **macOS** (Apple Silicon / Intel) y **Debian/Ubuntu** (VPS, GCP, AWS).

Un solo comando configura: shell, editor, git, herramientas cloud, Kubernetes y mas.

## Instalacion

```bash
git clone https://github.com/kr0nicas/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

Simulacion sin cambios:

```bash
./install.sh --dry-run
```

## Que incluye

### Shell y Terminal

| Herramienta | Descripcion |
|---|---|
| **zsh** | Shell principal con autosuggestions y syntax highlighting (plugins via brew/apt) |
| **starship** | Prompt minimalista con info de git/k8s/python/go |
| **tmux** | Multiplexor de terminal con TPM (plugin manager) |
| **fzf** | Fuzzy finder para archivos, historial y branches |
| **zoxide** | `cd` inteligente que aprende tus directorios frecuentes |
| **direnv** | Variables de entorno automaticas por directorio (.envrc) |

### CLI Modernas (Rust-powered)

| Herramienta | Reemplaza | Descripcion |
|---|---|---|
| **eza** | `ls` | Listados con iconos, colores y estado git |
| **bat** | `cat` | Visualizacion con syntax highlighting |
| **ripgrep** (`rg`) | `grep` | Busqueda ultrarapida en codigo |
| **fd** | `find` | Busqueda de archivos simple y rapida |
| **delta** | `diff` | Git diff con syntax highlighting side-by-side |
| **sd** | `sed` | Find & replace moderno |
| **dust** | `du` | Analizador de disco visual |
| **lazygit** | — | TUI interactiva para git |
| **git-extras** | — | Comandos extra de git (summary, changelog, etc.) |
| **btop** | `htop` | Monitor de sistema (CPU, RAM, disco, red) |
| **curlie** | `curl` | HTTP client con formato legible |
| **jless** | — | Visor interactivo de JSON |

### Editor: Neovim

Config 100% Lua en `config/nvim/` con lazy.nvim. Tema: **Catppuccin Mocha**.

| Plugin | Funcion |
|---|---|
| **telescope.nvim** | Fuzzy finder (archivos, grep, buffers, git) |
| **nvim-treesitter** | Syntax highlighting avanzado |
| **mason.nvim** | Gestion automatica de LSP servers |
| **nvim-lspconfig** | Go, Python, Lua, YAML, JSON, Bash, Terraform, Docker, TypeScript, Ansible |
| **nvim-cmp** | Autocompletado con LSP, snippets, buffer y path |
| **which-key.nvim** | Popup de keybindings al presionar Space |
| **oil.nvim** | File explorer como buffer (abrir con `-`) |
| **conform.nvim** | Formateo al guardar (black, goimports, jq, terraform fmt) |
| **nvim-lint** | Linting asincrono (flake8, yamllint, shellcheck, tflint) |
| **gitsigns.nvim** | Signos de cambios git en el gutter |
| **vim-fugitive** | Comandos git dentro del editor |
| **lualine.nvim** | Statusline con branch, diagnosticos, encoding |
| **mini.nvim** | Pairs, surround, comment |

### Cloud e Infraestructura

| Herramienta | Descripcion |
|---|---|
| **terraform** | Infrastructure as Code |
| **awscli** | CLI de Amazon Web Services |
| **azure-cli** | CLI de Microsoft Azure |
| **gcloud** | CLI de Google Cloud (lazy-loaded en zshrc) |

### Kubernetes

| Herramienta | Descripcion |
|---|---|
| **kubectl** | CLI oficial de Kubernetes |
| **helm** | Package manager para K8s |
| **k9s** | TUI para gestionar clusters en tiempo real |
| **kubectx/kubens** | Cambio rapido de contexto y namespace |
| **stern** | Tail de logs multi-pod |
| **kustomize** | Gestion de manifests K8s |
| **istioctl** | CLI de Istio service mesh |
| **kubectl-neat** | Limpia YAMLs de metadata generada |
| **viddy** | `watch` moderno con diff visual |
| **kubecolor** | Colorea output de kubectl |

### Seguridad

| Herramienta | Descripcion |
|---|---|
| **trivy** | Scanner de vulnerabilidades (containers, IaC, repos) |
| **tfsec** | Analisis estatico de Terraform (shift-left) |
| **vault** | Gestor de secrets HashiCorp |
| **sops** | Encriptacion de secrets en repos |
| **age** | Encriptacion moderna (backend para sops) |
| **pass** | Gestor de passwords con GPG |

### Lenguajes

| Lenguaje | Tooling |
|---|---|
| **Go** | `go` + `gopls` (LSP) + `gosec` |
| **Python** | `uv` (gestor moderno, reemplaza pip/pyenv/virtualenv) + `pyright` (LSP) |
| **Java** | `openjdk@17` + `jenv` + `maven` + `gradle` |
| **Node.js** | `fnm` (auto-detecta `.nvmrc`/`.node-version` por proyecto) + LTS |
| **Lua** | `lua_ls` (LSP para config nvim) |

### Git

Config en `.gitconfig` con:
- Editor: nvim
- Pager: delta (side-by-side, line numbers, tema Catppuccin)
- Merge conflicts: zdiff3
- Aliases: `st`, `co`, `br`, `cm`

### SSH

Selector interactivo de hosts con `s` (usa fzf + `~/.ssh/config`).
ControlMaster activo: reutiliza conexiones (segundo ssh es instantaneo, keepalive cada 60s).

**Colores de fondo por entorno** (`config/ssh/colors.conf`): al hacer `ssh prod-*`, `staging-*`, `gcp-*`, etc. la terminal cambia de color para identificar visualmente el contexto y evitar accidentes en produccion. Patrones editables; override local en `~/.ssh/colors.conf` (no symlinked).

### Terminal: WezTerm

Config cross-platform en `config/wezterm/wezterm.lua` (macOS + WSL2 Windows). Tema Catppuccin Mocha, fuente JetBrainsMono Nerd Font.
En WSL2 el symlink se crea automaticamente en `%USERPROFILE%\.config\wezterm\` (requiere Modo Desarrollador o PowerShell admin).

### Claude Code

- `config/claude/settings.json` — symlinked a `~/.claude/settings.json`. Statusline custom, plugins habilitados (superpowers, frontend-design, code-review), marketplaces extra.
- `config/claude/statusline.sh` — statusline portable (Mac + Linux + WSL).
- `config/claude/settings.local.json.example` — plantilla para overrides locales por maquina (no commiteado, sembrado en primer install).
- `install.sh` ancla `claude` al build nativo (`~/.local/bin/claude`) para evitar que fnm/npm rompa el PATH al cambiar de version de Node.

### Scripts locales

`config/bin/` se enlaza a `~/.local/bin/`:
- `cn` — wrapper de `@continuedev/cli` que localiza el node de fnm/nvm sin requerir que el version manager este cargado en el shell actual.

### Tmux Sessionizer

`t` abre un selector fzf de proyectos (`~/projects`, `~/go/src`) y crea/attacha sesion tmux.

### Prompt: Starship

Config en `config/starship/starship.toml` con tema Catppuccin Mocha. Muestra:
- OS icon, directorio, git branch/status
- Kubernetes context/namespace, GCloud project
- Node.js, Go, Python, Rust (solo si hay archivos relevantes)
- Tiempo de ejecucion (>2s), RAM (>60%), hora

## Estructura de archivos

```
~/dotfiles/
  install.sh                  # Instalador cross-platform
  Brewfile                    # Paquetes macOS (brew bundle)
  zshrc                       # Config de zsh
  tmux.conf                   # Config de tmux
  .gitconfig                  # Config de git + delta
  install-fonts-windows.ps1   # Nerd Fonts para WSL/Windows
  get-docker.sh               # Helper instalacion Docker
  vimrc                       # Fallback vim (sin nvim)
  CHEAT_CODES.md, VIM_GUIA.md # Notas personales
  config/
    nvim/                     # Config Neovim (Lua)
      init.lua
      lua/config/             # options, keymaps, autocmds, lazy bootstrap
      lua/plugins/            # colorscheme, treesitter, telescope, lsp, git, editor, ui, which-key, oil
    starship/
      starship.toml           # Config del prompt
    direnv/
      direnv.toml             # Whitelist de directorios confiables
    claude/
      settings.json           # Config Claude Code (statusline, plugins)
      statusline.sh           # Statusline portable Mac/Linux/WSL
      settings.local.json.example  # Plantilla overrides locales
    wezterm/
      wezterm.lua             # Config terminal Mac + WSL2
    ssh/
      colors.conf             # Color de fondo por entorno SSH
    bin/
      cn                      # Wrapper de @continuedev/cli
```

## Symlinks creados por install.sh

```
~/.zshrc                       -> ~/dotfiles/zshrc
~/.tmux.conf                   -> ~/dotfiles/tmux.conf
~/.gitconfig                   -> ~/dotfiles/.gitconfig
~/.config/nvim                 -> ~/dotfiles/config/nvim
~/.config/starship.toml        -> ~/dotfiles/config/starship/starship.toml
~/.config/direnv/direnv.toml   -> ~/dotfiles/config/direnv/direnv.toml
~/.claude/settings.json        -> ~/dotfiles/config/claude/settings.json
~/.claude/statusline.sh        -> ~/dotfiles/config/claude/statusline.sh
~/.ssh/colors.conf             -> ~/dotfiles/config/ssh/colors.conf
~/.config/wezterm/wezterm.lua  -> ~/dotfiles/config/wezterm/wezterm.lua  (en WSL2: lado Windows)
~/.local/bin/cn                -> ~/dotfiles/config/bin/cn
```

## WSL — Instalar Nerd Fonts en Windows

Los iconos del prompt (starship, eza) los renderiza el terminal de Windows, no WSL.
Ejecuta esto **una sola vez** desde PowerShell como Administrador:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
# Opcion A: desde PowerShell en Windows
.\install-fonts-windows.ps1

# Opcion B: directamente desde WSL
powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ~/dotfiles/install-fonts-windows.ps1)"
```

Luego configura la fuente en tu terminal:
- **Windows Terminal**: `Ctrl+,` → perfil WSL → Appearance → Font face → `JetBrainsMono Nerd Font`
- **VS Code**: `"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font"`

## Post-instalacion

```bash
source ~/.zshrc                    # Recargar shell
nvim                               # Lazy.nvim instala plugins automaticamente
tmux && prefix + I                 # Instalar plugins de tmux
```

## Actualizar

```bash
dots    # alias: commit + push de ~/dotfiles
```

---

Mantenido por Jorge Ochoa (kr0nicas) - 2026
