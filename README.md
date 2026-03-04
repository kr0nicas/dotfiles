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
| **zsh** | Shell principal con autosuggestions y syntax highlighting |
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
| **lazygit** | — | TUI interactiva para git |

### Editor: Neovim

Config 100% Lua en `config/nvim/` con lazy.nvim. Tema: **Catppuccin Mocha**.

| Plugin | Funcion |
|---|---|
| **telescope.nvim** | Fuzzy finder (archivos, grep, buffers, git) |
| **nvim-treesitter** | Syntax highlighting avanzado |
| **mason.nvim** | Gestion automatica de LSP servers |
| **nvim-lspconfig** | Go, Python, Lua, YAML, JSON, Bash, Terraform, Docker, TypeScript, Ansible |
| **nvim-cmp** | Autocompletado con LSP, snippets, buffer y path |
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

### Seguridad

| Herramienta | Descripcion |
|---|---|
| **trivy** | Scanner de vulnerabilidades (containers, IaC, repos) |
| **sops** | Encriptacion de secrets en repos |
| **age** | Encriptacion moderna (backend para sops) |
| **pass** | Gestor de passwords con GPG |

### Lenguajes

| Lenguaje | Tooling |
|---|---|
| **Go** | `go` + `gopls` (LSP) + `gosec` |
| **Python** | `uv` (gestor moderno) + `pyright` (LSP) |
| **Java** | `openjdk` + `jenv` + `maven` + `gradle` |
| **Node.js** | `nvm` (lazy-loaded) + LTS |
| **Lua** | `lua_ls` (LSP para config nvim) |

### Git

Config en `.gitconfig` con:
- Editor: nvim
- Pager: delta (side-by-side, line numbers, tema Catppuccin)
- Merge conflicts: zdiff3
- Aliases: `st`, `co`, `br`, `cm`

## Estructura de archivos

```
~/dotfiles/
  install.sh              # Instalador cross-platform
  Brewfile                # Paquetes macOS (brew bundle)
  zshrc                   # Config de zsh
  tmux.conf               # Config de tmux
  .gitconfig              # Config de git + delta
  config/
    nvim/                 # Config Neovim (Lua)
      init.lua
      lua/config/         # options, keymaps, autocmds, lazy bootstrap
      lua/plugins/        # colorscheme, treesitter, telescope, lsp, git, editor, ui
    starship/
      starship.toml       # Config del prompt
```

## Symlinks creados por install.sh

```
~/.zshrc           -> ~/dotfiles/zshrc
~/.tmux.conf       -> ~/dotfiles/tmux.conf
~/.gitconfig       -> ~/dotfiles/.gitconfig
~/.config/nvim     -> ~/dotfiles/config/nvim
~/.config/starship.toml -> ~/dotfiles/config/starship/starship.toml
```

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
