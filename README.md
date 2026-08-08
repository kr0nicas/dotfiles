<div align="center">

# ⚡ Dotfiles SRE 2026

**Cross-platform dotfiles para SRE** — un solo `./install.sh` configura todo tu entorno.

[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue?style=flat-square)](#)
[![Shell](https://img.shields.io/badge/shell-zsh-89e051?style=flat-square&logo=gnu-bash&logoColor=white)](#)
[![Editor](https://img.shields.io/badge/editor-Neovim-57A143?style=flat-square&logo=neovim&logoColor=white)](#)
[![Theme](https://img.shields.io/badge/theme-Catppuccin%20Mocha-cba6f7?style=flat-square)](#)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/kr0nicas/dotfiles?style=flat-square&color=fab387)](https://github.com/kr0nicas/dotfiles/commits/main)
[![Stars](https://img.shields.io/github/stars/kr0nicas/dotfiles?style=flat-square&color=f9e2af)](https://github.com/kr0nicas/dotfiles/stargazers)

</div>

---

## 📑 Tabla de contenidos

- [⚡ Quickstart](#-quickstart)
- [✨ Highlights](#-highlights)
- [🐚 Shell y terminal](#-shell-y-terminal)
- [🦀 CLIs modernas (Rust-powered)](#-clis-modernas-rust-powered)
- [📝 Editor — Neovim](#-editor--neovim)
- [☁️ Cloud e infraestructura](#️-cloud-e-infraestructura)
  - [`gcx` — cambiar de cuenta y proyecto en GCP](#gcx--cambiar-de-cuenta-y-proyecto-en-gcp)
- [☸️ Kubernetes](#️-kubernetes)
- [🔐 Seguridad](#-seguridad)
- [💻 Lenguajes](#-lenguajes)
- [🎨 Prompt — Starship](#-prompt--starship)
- [🌐 SSH](#-ssh)
- [🖥️ WezTerm](#️-wezterm)
- [🖥️ iTerm2 (macOS)](#️-iterm2-macos)
- [🤖 Claude Code](#-claude-code)
- [🔧 Git](#-git)
- [🗂️ Estructura de archivos](#️-estructura-de-archivos)
- [🔗 Symlinks creados](#-symlinks-creados)
- [🪟 WSL — Nerd Fonts en Windows](#-wsl--nerd-fonts-en-windows)
- [🔒 Arnés de reglas y trazabilidad](#-arnés-de-reglas-y-trazabilidad)
- [🛡️ Notas de seguridad](#️-notas-de-seguridad)
- [🧪 Plataformas probadas](#-plataformas-probadas)
- [❓ FAQ](#-faq)
- [📚 Referencias](#-referencias)
- [🔄 Post-instalacion y actualizacion](#-post-instalacion-y-actualizacion)

---

## ⚡ Quickstart

```bash
git clone https://github.com/kr0nicas/dotfiles.git ~/dotfiles
cd ~/dotfiles && ./install.sh
```

### Instalación modular

`install.sh` acepta flags compositivos para adaptarse al tipo de máquina:

```bash
./install.sh --dry-run                # Simula sin cambios
./install.sh --minimal                # Solo terminal env (zsh, tmux, nvim, langs) — ideal VPS/contenedores
./install.sh --no-gui                 # Sin VSCode/Brave/Spotify (servidor con DE pero sin apps)
./install.sh --no-cloud --no-k8s      # Workstation sin SRE tools
./install.sh --help                   # Ver todas las opciones
```

| Flag | Omite |
|---|---|
| `--minimal` | Cloud + Kubernetes + GUI (todo lo opcional) |
| `--no-cloud` | aws, azure, terraform, vault, tflint, gcloud |
| `--no-k8s` | kubectl, helm, k9s, stern, kubectx, docker |
| `--no-gui` | VSCode + extensiones, Brave, Spotify, Postman, ngrok |

El `Brewfile` base (siempre instalado) cubre: shell, CLIs modernas, nvim + linters, lenguajes, security y fonts.

Soportado en **macOS** (Apple Silicon / Intel) y **Debian/Ubuntu** (VPS, GCP, AWS). Ver [matriz completa](#-plataformas-probadas).

> 💡 Si ya tienes un `.zshrc`, `.tmux.conf`, etc., el installer **respalda automáticamente** a `<archivo>.bak.<timestamp>` antes de pisar. Nunca pierdes config existente.

---

## ✨ Highlights

- 🌍 **Cross-platform real** — un solo `install.sh` distingue macOS (Brewfile) vs Linux (apt + binarios de GitHub releases, sin sudo).
- 🦀 **Stack 2026** — CLIs Rust modernas (`eza`, `bat`, `rg`, `fd`, `delta`), Neovim 0.11+ con API nueva de LSP, `fnm` + `uv` para gestion de runtimes.
- ☸️ **SRE-ready** — Kubernetes, Terraform, AWS/GCP/Azure CLIs, Vault, Trivy, tfsec — listo para clusters de produccion.
- 🎨 **Identidad visual coherente** — Catppuccin Mocha en nvim/tmux/starship/delta + colores de fondo SSH por entorno (prod en rojo, staging en naranja...) para evitar accidentes en produccion.

---

## 🐚 Shell y terminal

| Herramienta | Descripcion |
|---|---|
| **zsh** | Shell principal con autosuggestions y syntax highlighting (plugins via brew/apt) |
| **starship** | Prompt minimalista con info de git/k8s/python/go |
| **tmux** | Multiplexor de terminal con TPM (plugin manager) |
| **fzf** | Fuzzy finder para archivos, historial y branches |
| **zoxide** | `cd` inteligente que aprende tus directorios frecuentes |
| **direnv** | Variables de entorno automaticas por directorio (`.envrc`) |

---

## 🦀 CLIs modernas (Rust-powered)

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

---

## 📝 Editor — Neovim

Config 100% Lua en `config/nvim/` con lazy.nvim. Tema: **Catppuccin Mocha**. Leader key: `<Space>`.

| Plugin | Funcion |
|---|---|
| **telescope.nvim** | Fuzzy finder (archivos, grep, buffers, git) |
| **nvim-treesitter** | Syntax highlighting avanzado |
| **mason.nvim** | Gestion automatica de LSP servers |
| **nvim-lspconfig** | Go, Python, Lua, YAML, JSON, Bash, Terraform, Docker, TypeScript, Ansible |
| **nvim-cmp** | Autocompletado con LSP, snippets, buffer y path |
| **which-key.nvim** | Popup de keybindings al presionar `<Space>` |
| **oil.nvim** | File explorer como buffer (abrir con `-`) |
| **conform.nvim** | Formateo al guardar (ruff_format, goimports, gofmt, jq, terraform fmt, stylua) |
| **nvim-lint** | Linting asincrono (ruff, yamllint, shellcheck, tflint) |
| **gitsigns.nvim** | Signos de cambios git en el gutter |
| **vim-fugitive** | Comandos git dentro del editor |
| **lualine.nvim** | Statusline con branch, diagnosticos, encoding |
| **mini.nvim** | Pairs, surround, comment |

**LSP bindings principales** (activos en `LspAttach`): `gd` definicion · `gr` referencias · `K` hover · `<Leader>ca` code action · `<Leader>rn` rename.

---

## ☁️ Cloud e infraestructura

| Herramienta | Descripcion |
|---|---|
| **terraform** | Infrastructure as Code |
| **awscli** | CLI de Amazon Web Services |
| **azure-cli** | CLI de Microsoft Azure |
| **gcloud** | CLI de Google Cloud (lazy-loaded en zshrc) |
| **rtk** | Comprime la salida de comandos para agentes IA |

### `gcx` — cambiar de cuenta y proyecto en GCP

Pickers `fzf` sobre tus configuraciones y proyectos de Google Cloud. Referencia
completa siempre a mano con `gcx -h`.

| Comando | Accion |
|---|---|
| `gcx` | Picker de configuraciones (cuenta + proyecto) |
| `gcx p` | Picker de proyectos de la cuenta activa (cache, instantaneo) |
| `gcx p -r` | Refresca la cache desde la API y abre el picker |
| `gcx use <config>` | Activa una configuracion por nombre |
| `gcx who` | Config, cuenta y proyecto activos |
| `gcx -h` | Hoja de referencia, con las configs listadas en vivo |

Atajos: `gcpers`, `gcit`, `gcfact`, `gckel` (delegan en `gcx use`) y `gcwho`.

Detalles que importan:

- **Ningun mensaje de estado esta hardcodeado** — todo se lee de `gcloud` en
  tiempo real, asi que la salida no puede desincronizarse de la realidad. Es el
  motivo por el que existe: los alias anteriores imprimian una cuenta fija que
  dejo de coincidir con la configuracion que activaban.
- **Cache por cuenta**, no por config: `~/.cache/gcp/projects-<cuenta>.list`.
  Dos configs de la misma cuenta comparten lista. Oculta los proyectos `sys-*`
  que autogenera Apps Script.
- **Se llama `gcx` y no `gcp`** porque `gcp` es el `cp` de GNU que instala
  coreutils.
- Suite propia: `zsh config/zsh/gcp.test.zsh` (45 tests, corren sin gcloud).

---

## ☸️ Kubernetes

| Herramienta | Descripcion |
|---|---|
| **kubectl** | CLI oficial de Kubernetes |
| **helm** | Package manager para K8s |
| **k9s** | TUI para gestionar clusters en tiempo real |
| **kubectx / kubens** | Cambio rapido de contexto y namespace |
| **stern** | Tail de logs multi-pod |
| **kustomize** | Gestion de manifests K8s |
| **istioctl** | CLI de Istio service mesh |
| **kubectl-neat** | Limpia YAMLs de metadata generada |
| **viddy** | `watch` moderno con diff visual |
| **kubecolor** | Colorea output de kubectl |

---

## 🔐 Seguridad

| Herramienta | Descripcion |
|---|---|
| **trivy** | Scanner de vulnerabilidades (containers, IaC, repos) |
| **tfsec** | Analisis estatico de Terraform (shift-left) |
| **vault** | Gestor de secrets HashiCorp |
| **sops** | Encriptacion de secrets en repos |
| **age** | Encriptacion moderna (backend para sops) |
| **pass** | Gestor de passwords con GPG |

---

## 💻 Lenguajes

| Lenguaje | Tooling |
|---|---|
| **Go** | `go` + `gopls` (LSP) + `gosec` |
| **Python** | `uv` (gestor moderno, reemplaza pip/pyenv/virtualenv) + `pyright` (LSP) |
| **Java** | `openjdk@17` + `jenv` + `maven` + `gradle` |
| **Node.js** | `fnm` (auto-detecta `.nvmrc`/`.node-version` por proyecto) + LTS |
| **Lua** | `lua_ls` (LSP para config nvim) |

---

## 🎨 Prompt — Starship

Config en `config/starship/starship.toml` con tema Catppuccin Mocha. Muestra:

- OS icon, directorio, git branch/status
- Kubernetes context/namespace, GCloud project
- Node.js, Go, Python, Rust (solo si hay archivos relevantes)
- Tiempo de ejecucion (>2s), RAM (>60%), hora

---

## 🌐 SSH

- 🔍 Selector interactivo de hosts con `s` (usa fzf + `~/.ssh/config`).
- ⚡ ControlMaster activo: reutiliza conexiones (segundo ssh es instantaneo, keepalive cada 60s).
- 🎨 **Colores de fondo por entorno** (`config/ssh/colors.conf`): al hacer `ssh prod-*`, `staging-*`, `gcp-*`, etc. la terminal cambia de color para identificar el contexto visualmente y evitar accidentes en produccion. Patrones editables; override local en `~/.ssh/colors.conf` (sin symlink).

Mapeo por defecto:

| Patron | Color | Etiqueta |
|---|---|---|
| `prod`, `prd` | 🔴 Rojo | PRODUCCION |
| `staging`, `stg` | 🟠 Naranja | STAGING |
| `qa` | 🟡 Amarillo | QA |
| `dev`, `gcp` | 🔵 Azul | DESARROLLO / GCP |
| `aws` | 🟢 Verde | AWS |
| `vps` | 🟣 Morado | VPS |
| `bastion` | ⚡ Magenta | BASTION |

---

## 🖥️ WezTerm

Config cross-platform en `config/wezterm/wezterm.lua` (macOS + WSL2 Windows). Tema Catppuccin Mocha.
En WSL2 el symlink se crea automaticamente en `%USERPROFILE%\.config\wezterm\` (requiere Modo Desarrollador o PowerShell admin).

La fuente se elige por `target_triple`, porque no es la misma en cada plataforma:

| Plataforma | Fuente | Quien la instala |
|---|---|---|
| macOS / Linux | Hack Nerd Font | `Brewfile` (`font-hack-nerd-font`) |
| WSL2 | JetBrainsMono Nerd Font | `install-fonts-windows.ps1` (renderiza Windows, no WSL) |

Va con `font_with_fallback`, asi que la caja que tenga la otra instalada tampoco se queda sin iconos.

---

## 🖥️ iTerm2 (macOS)

`config/iterm2/dotfiles.json` es un **Dynamic Profile**: iTerm2 lee todo lo que haya en
`~/Library/Application Support/iTerm2/DynamicProfiles/` y lo recarga en caliente, asi que basta el symlink — no hay que importar nada a mano ni exportar el plist.

El perfil se llama **SRE 2026** y fija fuente `Hack Nerd Font Mono 14`, tema Catppuccin Mocha y `Option` como `Esc+` (sin eso los `M-h/j/k/l` de `tmux.conf` no llegan).

Un paso manual, una sola vez por maquina: iTerm2 no permite marcar un dynamic profile como predeterminado desde el JSON.

```
Settings (⌘,) → Profiles → SRE 2026 → Other Actions… → Set as Default
```

Si ves `?` en lugar de iconos en `ls`/prompt, es que la ventana sigue con el perfil viejo: la fuente no tiene glifos Nerd.

---

## 🤖 Claude Code

- `config/claude/settings.json` → symlinked a `~/.claude/settings.json`. Statusline custom, plugins habilitados (superpowers, frontend-design, code-review), marketplaces extra.
- `config/claude/statusline.sh` → statusline portable (Mac + Linux + WSL).
- `config/claude/CLAUDE.md` → symlinked a `~/.claude/CLAUDE.md`. Instrucciones globales de usuario: solo los comandos propios (`gcx`, `dots`, `t`, `sp`, `cn`) y las reglas que Claude no puede deducir. Deliberadamente corto — se carga en cada sesion de cada proyecto.
- `config/claude/settings.local.json.example` → plantilla para overrides locales por maquina (no commiteada, sembrada en primer install).
- `install.sh` ancla `claude` al build nativo (`~/.local/bin/claude`) para evitar que fnm/npm rompa el `PATH` al cambiar de version de Node.

---

## 🔧 Git

Config en `.gitconfig` con:

- Editor: nvim
- Pager: delta (side-by-side, line numbers, tema Catppuccin)
- Merge conflicts: zdiff3
- Aliases: `st`, `co`, `br`, `cm`

---

## 🗂️ Estructura de archivos

```
~/dotfiles/
├── install.sh                   # Orquestador: flags, presets y orden de las fases
├── lib/                         # Una fase por archivo (el "como" del instalador)
│   ├── common.sh                # Logging, verificacion de checksums, banner
│   ├── menu.sh                  # Ayuda, menus interactivos, deteccion de update
│   ├── detect.sh                # SO, arquitectura, dependencias criticas
│   ├── packages.sh              # brew bundle (macOS) / apt (Debian-Ubuntu)
│   ├── runtimes.sh              # fnm+Node, fzf, starship, zoxide, uv
│   ├── binaries.sh              # GitHub Releases + checksums (solo Linux)
│   ├── editors.sh               # tmux/TPM, Neovim/lazy.nvim, Claude Code
│   ├── symlinks.sh              # Todos los symlinks
│   ├── repo.sh                  # Hooks de git (core.hooksPath -> .githooks)
│   └── verify.sh                # Limpieza de cache zsh + resumen final
├── .githooks/                   # commit-msg, pre-commit, pre-push + suite propia
├── scripts/                     # changelog.sh, github-topics-manager.sh
├── CHANGELOG.md                 # Generado por scripts/changelog.sh, no se edita a mano
├── Brewfile                     # Paquetes macOS (brew bundle)
├── zshrc                        # Config de zsh
├── tmux.conf                    # Config de tmux
├── .gitconfig                   # Config de git + delta
├── install-fonts-windows.ps1    # Nerd Fonts para WSL/Windows
├── vimrc                        # Fallback vim (sin nvim) — symlinkeado a ~/.vimrc
├── CHEAT_CODES.md, VIM_GUIA.md  # Notas personales
├── docs/
│   ├── reports/                 # Informes puntuales (auditorias, inventarios)
│   └── superpowers/             # Specs y planes de implementacion
└── config/
    ├── nvim/                    # Config Neovim (Lua)
    │   ├── init.lua
    │   └── lua/
    │       ├── config/          # options, keymaps, autocmds, lazy bootstrap
    │       └── plugins/         # colorscheme, treesitter, telescope, lsp, git, editor, ui, which-key, oil
    ├── starship/
    │   └── starship.toml        # Config del prompt
    ├── direnv/
    │   └── direnv.toml          # Whitelist de directorios confiables
    ├── claude/
    │   ├── settings.json        # Config Claude Code (statusline, plugins)
    │   ├── statusline.sh        # Statusline portable Mac/Linux/WSL
    │   ├── CLAUDE.md            # Instrucciones globales de usuario
    │   └── settings.local.json.example   # Plantilla overrides locales
    ├── wezterm/
    │   └── wezterm.lua          # Config terminal Mac + WSL2
    ├── iterm2/
    │   └── dotfiles.json        # Dynamic Profile "SRE 2026" (solo macOS)
    ├── ssh/
    │   └── colors.conf          # Color de fondo por entorno SSH
    ├── zsh/
    │   ├── gcp.zsh              # Comando gcx: switcher de cuentas/proyectos GCP
    │   └── gcp.test.zsh         # Suite de gcx (45 tests, corre sin gcloud)
    └── bin/
        └── cn                   # Wrapper de @continuedev/cli
```

---

## 🔗 Symlinks creados

```
~/.zshrc                        →  ~/dotfiles/zshrc
~/.tmux.conf                    →  ~/dotfiles/tmux.conf
~/.gitconfig                    →  ~/dotfiles/.gitconfig
~/.vimrc                        →  ~/dotfiles/vimrc
~/.config/nvim                  →  ~/dotfiles/config/nvim
~/.config/starship.toml         →  ~/dotfiles/config/starship/starship.toml
~/.config/direnv/direnv.toml    →  ~/dotfiles/config/direnv/direnv.toml
~/.claude/settings.json         →  ~/dotfiles/config/claude/settings.json
~/.claude/statusline.sh         →  ~/dotfiles/config/claude/statusline.sh
~/.claude/CLAUDE.md             →  ~/dotfiles/config/claude/CLAUDE.md
~/.ssh/colors.conf              →  ~/dotfiles/config/ssh/colors.conf
~/.config/wezterm/wezterm.lua   →  ~/dotfiles/config/wezterm/wezterm.lua   (WSL2: lado Windows)
~/.local/bin/cn                 →  ~/dotfiles/config/bin/cn

~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json
                                →  ~/dotfiles/config/iterm2/dotfiles.json   (solo macOS)
```

---

## 🪟 WSL — Nerd Fonts en Windows

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

---

## 🔒 Arnés de reglas y trazabilidad

`main` está protegido: el trabajo entra por rama y PR con CI en verde.

| Hook | Qué comprueba | Degrada si falta la herramienta |
|---|---|---|
| `commit-msg` | Formato del mensaje, tipo, ámbito, longitud | No |
| `pre-commit` | Lint de lo staged | Sí |
| `pre-commit` | Secretos (claves, tokens, `.env`) | No |
| `pre-push` | Suites completas + guardia de `main` | Parcial |

Se activan con `./install.sh`. Comprobar: `git config --get core.hooksPath` → `.githooks`.

`CHANGELOG.md` es un **archivo generado** por `scripts/changelog.sh`; el CI falla si está desactualizado. No lo edites a mano.

Spec del arnés: `docs/superpowers/specs/2026-08-08-arnes-trazabilidad-design.md`

---

## 🛡️ Notas de seguridad

`install.sh` usa los instaladores oficiales upstream (`curl … | bash`) para fnm, starship, zoxide, uv, trivy, helm y claude — la vía documentada por cada proyecto. Trade-off aceptado por ergonomía. Antes de instalar en una máquina nueva:

- Corre `./install.sh --dry-run` para ver exactamente qué se descarga.
- Verifica que todas las URLs sean HTTPS desde hosts oficiales (lo son hoy).
- Si necesitas un entorno hardened, reemplaza cada bloque por descarga + verificación SHA256.

Los binarios de GitHub Releases (k9s, lazygit, stern, sops, etc.) **sí se verifican**: se descargan a disco y se comparan contra el `checksums.txt` del propio release antes de instalarse. Un checksum que no coincide **aborta el instalador entero** — distinguir eso de "no se pudo comprobar" es lo único que separa una descarga corrupta de una manipulada.

Algunos proyectos no publican checksums en sus releases (`delta` y `dust`, hoy). Esos se instalan igual, pero con un warning visible por herramienta: el hueco queda auditable en la salida, no escondido.

---

## 🧪 Plataformas probadas

| OS | Versión | Arch | Estado |
|---|---|---|---|
| 🍎 macOS | Sonoma 14.x | Apple Silicon (M1/M2/M3) | ✅ Daily driver |
| 🍎 macOS | Sequoia 15.x | Apple Silicon | ✅ Probado |
| 🐧 Ubuntu | 24.04 LTS | x86_64 / arm64 | ✅ Probado |
| 🐧 Ubuntu | 22.04 LTS | x86_64 | ✅ Probado |
| 🐧 Debian | 12 (Bookworm) | x86_64 / arm64 | ✅ Probado |
| 🪟 WSL2 | Ubuntu 24.04 sobre Windows 11 | x86_64 | ✅ Probado (WezTerm en Windows) |
| 🐧 Otras distros | Fedora, Arch, Alpine, etc. | — | ⚠️ No probado (puede requerir ajustes en `install.sh`) |

> Reporta issues con tu plataforma en [github.com/kr0nicas/dotfiles/issues](https://github.com/kr0nicas/dotfiles/issues).

---

## ❓ FAQ

**¿Es seguro correr `./install.sh` si ya tengo configs existentes?**
Sí. `safe_link()` respalda automáticamente cualquier `.zshrc`, `.tmux.conf`, etc. existente a `<archivo>.bak.<timestamp>` antes de pisar. Igual recomendamos `--dry-run` primero.

**¿Necesito sudo?**
En macOS: no (todo via Homebrew en `/opt/homebrew` o `/usr/local`).
En Linux: sí, solo para `apt install` y agregar repos firmados a `/etc/apt/keyrings`. Binarios SRE van a `~/.local/bin` (sudoless).

**¿Cómo actualizo después de cambios upstream?**
```bash
cd ~/dotfiles && git pull && ./install.sh
```
`install.sh` es idempotente: detecta lo ya instalado y solo aplica diffs.

**¿Funciona sin internet?**
No. `install.sh` descarga paquetes y binarios. Pero una vez instalado, todo funciona offline.

**`gh_latest_url` falla con "rate limit"**
La API de GitHub anónima permite 60 req/hora. Auth con `gh auth login` antes de instalar.

**¿Por qué `lazy-lock.json` está en `.gitignore`?**
Decisión filosófica: priorizamos "instala lo último al re-instalar" sobre reproducibilidad estricta. Si prefieres pinned plugins, abre un issue.

**Algo se rompió. ¿Cómo restauro mi config previa?**
Los backups están en `~/<archivo>.bak.<timestamp>`. Por ejemplo:
```bash
ls ~/.zshrc.bak.*    # listar backups
mv ~/.zshrc.bak.20260529-103045 ~/.zshrc   # restaurar uno
```

**¿Puedo instalar solo lo terminal sin las herramientas de cloud/k8s?**
Sí. Usa `./install.sh --minimal` (solo base) o combina `--no-cloud`, `--no-k8s`, `--no-gui`. Ver [Quickstart](#-quickstart).

---

## 📚 Referencias

- [`CHEAT_CODES.md`](CHEAT_CODES.md) — Atajos de tmux, fzf, k9s, lazygit, kubectx y aliases custom
- [`VIM_GUIA.md`](VIM_GUIA.md) — Guía rápida de Vim/Neovim (motions, comandos, plugins)
- [`CLAUDE.md`](CLAUDE.md) — Instrucciones internas para Claude Code (arquitectura del repo)
- [`Mac-Optimization/`](Mac-Optimization/) — Notas de optimización macOS *(WIP)*

---

## 🔄 Post-instalacion y actualizacion

```bash
source ~/.zshrc              # Recargar shell
nvim                         # Lazy.nvim instala plugins automaticamente
tmux && prefix + I           # Instalar plugins de tmux (prefix = C-a)
```

Actualizar el repo:

```bash
dots 'fix(zshrc): quitar alias que rompía du'   # rama + commit + push + PR
```

---

<div align="center">

**Mantenido por [Jorge Ochoa (kr0nicas)](https://github.com/kr0nicas) · 2026**

Licencia [MIT](LICENSE) — uso publico, contribuciones bienvenidas.

</div>
