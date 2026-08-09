# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Cross-platform dotfiles for Jorge Ochoa (kr0nicas) — SRE 2026 setup targeting **macOS** (Apple Silicon/Intel) and **Debian/Ubuntu** (VPS, GCP, AWS). A single `./install.sh` bootstraps the full environment.

## Installation & common commands

```bash
./install.sh              # Interactive menu (or full install if stdin is not a TTY)
./install.sh --dry-run    # Simulate without making changes (menu still runs if interactive)
./install.sh --update     # Detect prior install → git pull --ff-only + re-apply (aborts if dirty)
./install.sh --vps        # VPS/server preset (base + cloud, no k8s/gui)
./install.sh --container  # Container/Docker preset (base only, ultra-minimal)
./install.sh --k8s-node   # Kubernetes node preset (base + cloud + k8s, no gui)
./install.sh --minimal    # Skip cloud, k8s, GUI (only base terminal env)
./install.sh --no-cloud   # Skip aws/azure/terraform/vault/gcloud
./install.sh --no-k8s     # Skip kubectl/helm/k9s/stern/kubectx/docker
./install.sh --no-gui     # Skip VSCode + extensions + Brave/Spotify/Postman
./install.sh --help       # Show all options

brew bundle --file=~/dotfiles/Brewfile   # Install/sync base macOS packages (cloud/k8s/gui in Brewfile.{cloud,k8s,gui})
source ~/.zshrc                          # Reload shell after config changes

zsh config/zsh/gcp.test.zsh              # Test suite del switcher gcx (45 tests, corre sin gcloud instalado)
zsh config/zsh/ssh.test.zsh              # Test suite de _ssh_target (13 tests, no abre ninguna conexión)
zsh -n zshrc && zsh -n config/zsh/gcp.zsh  # Chequeo de sintaxis zsh (shellcheck NO sirve: no soporta zsh)
```

Post-install:
```bash
nvim                    # lazy.nvim auto-installs plugins on first open
tmux && prefix + I      # Install tmux plugins via TPM (prefix is C-a)
```

Update dotfiles:
```bash
dots 'fix(zshrc): quitar alias que rompía du'   # rama + commit + push + PR
```

## Flujo de trabajo (obligatorio)

Nunca se commitea directo a `main`: está protegido en GitHub y `pre-push` lo rechaza antes.

1. **Rama antes de tocar código.** `git switch -c feat/<ámbito>-<asunto>`. Si ya empezaste en `main`, mueve el trabajo a una rama antes de commitear.
2. **Commit al cerrar cada unidad de trabajo**, sin esperar a que te lo pidan. El cuerpo explica el *porqué*; el diff ya dice el qué.
3. **PR al terminar.** `gh pr create --fill`, y `gh pr merge --merge --delete-branch` (`--no-ff`, nunca squash: el CHANGELOG se genera de esa estructura).
4. **Regenerar el CHANGELOG** con `./scripts/changelog.sh` como último paso antes del push final. El CI falla si difiere. Va **siempre en su propio commit**, que no toca nada más — de lo contrario el archivo es insatisfacible: el commit que lo regenera se excluye de su propio listado, así que mezclarlo con otro cambio deja el CHANGELOG desactualizado en el momento en que se genera.

Convención de commits, validada por `.githooks/commit-msg`:

```
<tipo>(<ámbito>): <asunto>

<el porqué>

Spec: docs/superpowers/specs/<archivo>.md
Refs: #12
```

- Tipos: `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`, `test`, `perf`, `build`, `revert`
- Ámbitos: lista cerrada en `.githooks/scopes.txt`. Si falta uno, añádelo ahí — no te saltes la regla.
- Asunto en minúscula, imperativo, sin punto final, ≤72 caracteres.

Los hooks se activan solos con `./install.sh` (`phase_repo` → `core.hooksPath`). Verificar con `git config --get core.hooksPath` → `.githooks`.

`git commit --no-verify` existe para emergencias reales, no para saltarse un mensaje mal escrito.

**No encadenes comandos detrás de un `git commit` en la misma invocación de shell.** El hook `commit-msg` rechaza el commit —un asunto de 73 caracteres basta— pero los ficheros se quedan en el índice, y lo que venga detrás de un `;` o de un `&&` mal puesto se ejecuta igual. Un `git add CHANGELOG.md && git commit -m 'chore(repo): regenerar CHANGELOG'` escrito a continuación se lleva **todo** el índice bajo ese mensaje: el trabajo real acaba commiteado como si fuera el CHANGELOG, y el CHANGELOG acaba fuera de su propio commit. Commitea aislado y comprueba con `git log --oneline -1` que existe antes de seguir. Esto vale doblemente para agentes, que agrupan comandos en una sola llamada por eficiencia.

### Dónde va un spec y dónde va el borrador

El trailer `Spec:` apunta a `docs/superpowers/`, que **sí está versionado**, no al directorio `.superpowers/` de la raíz, que **no lo está**. Son dos sitios distintos y confundirlos es fácil porque comparten nombre:

| Ruta | Versionado | Qué es |
|---|---|---|
| `docs/superpowers/specs/` | Sí | Diseños aprobados, uno por trabajo. `AAAA-MM-DD-<tema>-design.md` |
| `docs/superpowers/plans/` | Sí | El plan de implementación de ese diseño, mismo prefijo de fecha |
| `docs/reports/` | Sí | Informes puntuales de trabajos que no dejaron código |
| `.superpowers/sdd/` | **No** | Borrador de agente: briefs por tarea, reports y diffs de review |

`.superpowers/sdd/` se autoignora con un `.gitignore` propio que contiene `*`. No es documentación y **no es fuente de verdad**: son notas de una sesión concreta, escritas mientras el trabajo estaba a medias, y contradicen al repo en cuanto el trabajo avanza. Léelo como arqueología si buscas por qué se decidió algo, nunca como referencia de cómo está el código hoy. Escribe ahí libremente; no hace falta limpiarlo.

Lo que sí se versiona lo citan los propios hooks: `.githooks/commit-msg`, `pre-commit` y `pre-push` llevan en su cabecera la línea `Spec: docs/superpowers/specs/2026-08-08-arnes-trazabilidad-design.md`. Si cambias el comportamiento de un hook, actualiza su spec.

## Architecture

### Cross-platform split

The OS split is the core architectural decision:
- **Brewfile** + **Brewfile.cloud** + **Brewfile.k8s** + **Brewfile.gui** — macOS only. `install.sh` calls `brew bundle` for the base file always, and the others conditionally based on `--no-cloud`/`--no-k8s`/`--no-gui` flags.
- **`lib/binaries.sh`** — Linux only. Downloads SRE tool binaries (k9s, lazygit, stern, delta, etc.) from GitHub releases into `$HOME/.local/bin` — no sudo required. K8s tools gated by `$INSTALL_K8S`, cloud tools by `$INSTALL_CLOUD`. Verifica checksums; ver la nota de seguridad en la cabecera de `install.sh`.
  - **Los linters de nvim-lint van gateados como en el Brewfile**: `shellcheck` y `yamllint` son base, `tflint` va con cloud (en macOS vive en `Brewfile.cloud`). Sin esto, nvim-lint daba ENOENT en Linux igual que daba en Python antes de ruff.
  - **`yamllint` y `sshuttle` son la excepción al patrón `gh_latest_*`**: son paquetes de Python sin binario estático, así que se instalan con `uv tool install`. Funciona porque `phase_runtimes` (que instala uv) corre antes que `phase_binaries` — no reordenes esas dos fases.
  - **Cuatro variables de arquitectura, no una.** `ARCH_TYPE` es `uname -m` crudo (`x86_64`/`aarch64`) y lo usan los proyectos que nombran assets con el triple de Rust o con uname (ruff, delta, dust, shellcheck, trippy, bandwhich, doggo); `ARCH` es la convención de Go (`amd64`/`arm64`) y la usan tflint, k9s, stern, sops, step, oha, dive, kubeshark; `GH_ARCH` traduce a `x86_64`/`arm64` para lazygit, kubectx, jless y lnav; y `X64_ARCH` llama `x64` a lo que las otras tres llaman `x86_64` o `amd64`, y la usan termshark y gitleaks. Elegir la equivocada descarga el asset de otra arquitectura sin error visible. **Comprueba el patrón contra el release real antes de commitear** — es la única forma de detectarlo.
  - **Las herramientas de red que son C compilado van por apt, no por `gh_latest_*`**: `mtr-tiny`, `nmap`, `socat`, `iperf3` y `tshark` no publican binarios estáticos. `mtr-tiny` y no `mtr` porque el segundo arrastra GTK en Debian. `tshark` obliga a `DEBIAN_FRONTEND=noninteractive`: su postinst abre un diálogo debconf que cuelga la instalación en CI.
- **zshrc** — single file with `if [[ "$OSTYPE" == "darwin"* ]]` guards for macOS-specific PATH entries and tools.

### install.sh + `lib/` (orquestador y fases)

`install.sh` (~120 líneas) decide **qué** se hace y en qué orden; el **cómo** vive en `lib/`, una fase por archivo. Para añadir una herramienta, toca el `lib/` que le corresponde, no el orquestador.

| Archivo | Responsabilidad |
|---|---|
| `install.sh` | Flags, presets, `SCRIPT_DIR`, carga de fases, orden de ejecución |
| `lib/common.sh` | Colores, logging (`log`/`ok`/`warn`/`err`), `sha256_of`, `verify_sha256`, banner |
| `lib/menu.sh` | `print_help`, menús interactivos, detección de instalación previa, `git pull` |
| `lib/detect.sh` | `phase_detect` — SO, arquitectura, dependencias críticas |
| `lib/packages.sh` | `phase_packages` — `brew bundle` (macOS) / `apt` (Debian-Ubuntu) |
| `lib/runtimes.sh` | `phase_runtimes` — fnm+Node, fzf, starship, zoxide, uv |
| `lib/binaries.sh` | `phase_binaries` — GitHub Releases + verificación de checksums (solo Linux) |
| `lib/editors.sh` | `phase_editors` — tmux/TPM, Neovim/lazy.nvim, Claude Code |
| `lib/symlinks.sh` | `phase_symlinks` — todos los symlinks |
| `lib/repo.sh` | `phase_repo` — hooks de git (`core.hooksPath` → `.githooks`) |
| `lib/verify.sh` | `phase_verify` — limpieza de caché zsh + resumen final |

Convenciones que hay que respetar al tocar esto:

- **`DOTFILES_DIR` se deriva de `SCRIPT_DIR`**, nunca de `$HOME/dotfiles`. Antes estaba fijo y clonar en otra ruta rompía todos los symlinks.
- **Las fases comparten globales a propósito.** `phase_detect` fija `IS_MAC`, `ARCH_TYPE`, `GH_ARCH` y los consumen las fases siguientes. No añadas `local` a esas asignaciones.
- **Los `source` en `install.sh` son explícitos, no un bucle**, para que `shellcheck -x` siga cada uno y analice el conjunto. Con un `source` construido por variable, shellcheck ve cada archivo aislado y reporta SC2034 en cascada.
- **`shellcheck -x -S warning install.sh`** es lo que exige el CI, y cubre todo `lib/`. No analices los `lib/` sueltos: darán falsos positivos.
- **Nada de `cd` suelto dentro de una fase.** Envuélvelo en un subshell; si no, un `cd` fallido deja las fases siguientes en el directorio equivocado.
- **Equivalencia al refactorizar**: `./install.sh --dry-run [flags]` es determinista. Captura la salida antes y después y compárala — es el oráculo que prueba que no cambiaste comportamiento.

### Symlinks (created by install.sh)

All config lives in `~/dotfiles/` and is symlinked into place:
```
~/.zshrc                    -> ~/dotfiles/zshrc
~/.tmux.conf                -> ~/dotfiles/tmux.conf
~/.gitconfig                -> ~/dotfiles/.gitconfig
~/.vimrc                    -> ~/dotfiles/vimrc          (fallback para cajas sin nvim, ver VIM_GUIA.md)
~/.config/nvim              -> ~/dotfiles/config/nvim/
~/.config/starship.toml     -> ~/dotfiles/config/starship/starship.toml
~/.config/direnv/direnv.toml -> ~/dotfiles/config/direnv/direnv.toml
~/.claude/settings.json     -> ~/dotfiles/config/claude/settings.json
~/.claude/statusline.sh     -> ~/dotfiles/config/claude/statusline.sh
~/.claude/CLAUDE.md         -> ~/dotfiles/config/claude/CLAUDE.md   (instrucciones globales de usuario)
~/.config/wezterm/wezterm.lua -> ~/dotfiles/config/wezterm/wezterm.lua
~/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json -> ~/dotfiles/config/iterm2/dotfiles.json  (solo macOS)
~/.ssh/colors.conf          -> ~/dotfiles/config/ssh/colors.conf
rtk config.toml             -> ~/dotfiles/config/rtk/config.toml  (macOS: ~/Library/Application Support/rtk/, Linux: ~/.config/rtk/)
```

`config/zsh/gcp.zsh` es la excepción: **no se symlinkea**. `zshrc` lo carga con un `source` por ruta directa (`$HOME/dotfiles/config/zsh/gcp.zsh`), igual que `~/.zshrc.local`. No añadas un symlink para él en `install.sh`.

### rtk (Rust Token Killer)

`brew "rtk"` (en `Brewfile.cloud`). Proxy en Rust que comprime la salida de comandos (kubectl, aws, docker, git, grep…) **antes de que la lea un agente de IA** — reduce 60–90% de tokens. Solo actúa sobre las llamadas Bash de Claude Code vía un `PreToolUse` hook; **no toca la shell interactiva**.

- **Config**: `config/rtk/config.toml` (symlinkeado por install.sh, ruta según OS). `[hooks].exclude_commands` excluye `terraform`/`tofu`/`helm`/`vault`/`gcloud`/`gsutil` para que el output de infra nunca se comprima (hoy rtk no los proxya; es defensa a futuro). `kubectl`/`aws` **sí** se comprimen.
- **Hook en Claude Code**: se registra con `rtk init -g --hook-only` (añade `hooks.PreToolUse` → `rtk hook claude` a `~/.claude/settings.json`). Como `settings.json` puede tener `skip-worktree`, ese cambio no siempre se versiona — re-ejecutar el comando en cada máquina es idempotente.
- **Uso**: `rtk gain` (ahorro de tokens), `RTK_DISABLED=1 <cmd>` (bypass puntual), `rtk init -g --uninstall` (quitar).

### gcx — switcher de cuentas y proyectos de GCP

`config/zsh/gcp.zsh`. Comando para saltar entre configuraciones (cuentas) y proyectos de Google Cloud con pickers `fzf`. Reemplazó a cuatro aliases que imprimían con `echo` una cuenta hardcodeada que ya no coincidía con la config que activaban.

```
gcx                Picker de configuraciones (cuenta + proyecto)
gcx p [-r]         Picker de proyectos de la cuenta activa (caché; -r refresca desde la API)
gcx use <config>   Activa una configuración por nombre
gcx who            Config, cuenta y proyecto activos
gcx -h             Hoja de referencia completa, con las configs listadas en vivo
```

El dispatcher acepta además `project` como sinónimo de `p`, y `--help`/`help` de `-h`. Los aliases viven en `zshrc` (búscalos con `grep -n 'gcx use' zshrc`, no por número de línea: se mueven): `gcpers`, `gcit`, `gcfact`, `gckel` (todos delegan en `gcx use`) y `gcwho`.

- **Principio de diseño, no negociable**: ningún mensaje de **estado** hardcodea cuenta ni proyecto — todo se lee de `gcloud` en tiempo real. Es la causa raíz del defecto original. La única excepción es la sección ALIASES de `gcx -h`, que es documentación estática. Si añades un mensaje, léelo de `gcloud`, nunca de una constante.
- **Se llama `gcx`, no `gcp`**: `gcp` es el `cp` de GNU que instala Homebrew coreutils (`/usr/local/bin/gcp`). El archivo `gcp.zsh`, los helpers `_gcp_*`, la variable `GCP_CACHE_DIR` y la caché `~/.cache/gcp` sí conservan el prefijo `gcp` a propósito: nombran el dominio (Google Cloud Platform), no el comando. No los "unifiques".
- **Trampa de `gcloud config configurations list`**: hay que usar `properties.core.account` y `properties.core.project`. Las formas cortas `account`/`project` devuelven **cadena vacía sin dar error** — el picker sale con columnas en blanco y ningún test unitario lo detecta.
- **Caché por cuenta, no por config**: `~/.cache/gcp/projects-<cuenta-sanitizada>.list`. Dos configs de la misma cuenta comparten archivo. Filtra los proyectos `^sys-` (autogenerados por Apps Script). Escritura atómica vía temporal + `mv`; si la API falla y hay caché previa, se conserva y se avisa.
- **`_gcp_config_table` es fuente única** de la tabla de configuraciones: la usan el picker y `gcx -h`. No dupliques su bloque `awk`.
- **Dependencia de `column`**: en Debian/Ubuntu viene en `bsdextrautils`, ya incluido en el bloque apt de `install.sh`. Sin él, los pickers y `gcx -h` fallan en los presets `--vps` y `--container`.
- **Tests**: `config/zsh/gcp.test.zsh`, 45 tests con arnés propio (`assert_eq`, `assert_contains`). Corren **sin gcloud instalado** — los que necesitan `gcloud` o `fzf` usan stubs eliminados con `unfunction` al cerrar su bloque. Mantén esa propiedad: la suite debe pasar en un contenedor sin SDK.

### zshrc load order

1. PATH setup (fzf bin and `~/.local/bin` prioritized to avoid version conflicts)
2. OS-specific PATHs (macOS: Homebrew, jenv, Android, Go; Linux: `~/.local/go`)
3. Tool init: `starship`, `direnv`
4. Lazy-loaded: `gcloud`/`gsutil`/`bq` (deferred until first call via the shared `_gcloud_lazy_load` helper — do not pass the caller's args to it), `fnm` (Node version manager)
5. `source config/zsh/gcp.zsh` — defines `gcx` and its `_gcp_*` helpers. Pure definitions, no gcloud calls at load time, so non-interactive shells and machines without the SDK are unaffected.
6. Plugins: `zsh-autosuggestions`, `zsh-syntax-highlighting` (searched across `/usr/share`, `/usr/local/share`, `/opt/homebrew/share`)
7. FZF keybindings (version-guarded: requires ≥0.48 for `fzf --zsh`)
8. Aliases and functions (`t` tmux sessionizer, `sp`/`ssh-pick`, GCP aliases delegating to `gcx use`)
9. `zoxide init` (must be last)
10. Local overrides: `~/.zshrc.local` (not synced — host-specific config)

### Neovim config (`config/nvim/`)

Entry: `init.lua` → loads `config.lazy`, `config.options`, `config.keymaps`, `config.autocmds`.

Plugin files in `lua/plugins/`:
- `lsp.lua` — Mason + mason-lspconfig + nvim-lspconfig (nvim 0.11+ API via `vim.lsp.enable()`) + nvim-cmp. gopls and terraformls are macOS-only (gated by `vim.uv.os_uname().sysname == "Darwin"`). **También vive aquí el stack de formato y lint**, no en `editor.lua`: conform.nvim (format on save: `ruff_format`, goimports, gofmt, jq, terraform_fmt, stylua) y nvim-lint (`ruff`, yamllint, shellcheck, tflint).
- `editor.lua` — solo mini.pairs, mini.surround y mini.comment
- `telescope.lua` — fuzzy finder
- `treesitter.lua` — syntax highlighting
- `git.lua` — gitsigns + vim-fugitive
- `oil.lua` — file explorer (open with `-`)
- `navigation.lua` — vim-tmux-navigator: `C-h/j/k/l` saltan entre splits de nvim y paneles de tmux. Fuera de tmux degrada a `<C-w>hjkl`, así que funciona igual en una caja sin multiplexor.
- `which-key.lua` — keybinding popup on `<Space>`
- `ui.lua`, `colorscheme.lua` — lualine, Catppuccin Mocha theme

Leader key: `<Space>`. Key LSP bindings active on `LspAttach`: `gd` (definition), `gr` (references), `K` (hover), `<Leader>ca` (code action), `<Leader>rn` (rename).

### Tmux (`tmux.conf`)

Prefix remapped to `C-a`. Key bindings:
- `|` / `-` — split horizontally/vertically (preserves cwd)
- `C-h/j/k/l` — navigate panes *and* nvim splits without prefix (vim-tmux-navigator)
- `M-h/j/k/l` — navigate panes without prefix; fallback puro de tmux, ignora si el pane corre nvim
- `M-1..5` — jump to window by number
- `Prefix + r` — reload config
- `Prefix + C-l` — clear screen (el `C-l` suelto ahora lo consume el navigator)
- Copy mode vi-style; clipboard auto-detected (pbcopy on Mac, xclip/xsel on Linux)

Plugins via TPM: tmux-sensible, tmux-resurrect, tmux-continuum (auto-save every 15min, auto-restore on start), tmux-yank, vim-tmux-navigator.

**Las dos mitades del navigator van juntas**: el plugin de TPM en `tmux.conf` y `config/nvim/lua/plugins/navigation.lua`. Si tocas una, toca la otra — con solo el lado tmux, `C-hjkl` dentro de nvim se traga las teclas y no navega. Y no redeclares `C-hjkl` en `config/nvim/lua/config/keymaps.lua`: ese archivo se carga después de `config.lazy` y pisaría los stubs de lazy, dejando el plugin sin cargar nunca.

### Language environment management

| Language | Tool | Notes |
|---|---|---|
| Node.js | `fnm` | Reads `.nvmrc` / `.node-version` per project. Init via `eval "$(fnm env --use-on-cd --shell zsh)"` |
| Python | `uv` | Replaces pip/virtualenv/pyenv. Use `uv venv` + `uv pip install` per project |
| Go | `GOPATH=$HOME/go` | Managed via `go.mod`; gopls LSP on macOS |
| Java | `jenv` + `openjdk@17` | Add `.java-version` file per project |

### `config/bin/cn`

Wrapper for `@continuedev/cli` — finds the fnm/nvm node binary without requiring nvm to be loaded in the current shell. Update this if the node version manager changes.

### `scripts/` y documentos sueltos

Lo que no cuelga de `install.sh` y solo se descubre con un `ls`:

| Archivo | Qué es |
|---|---|
| `scripts/changelog.sh` | Regenera `CHANGELOG.md` desde el historial: merge commits si la feature ya está en `main`, `main..HEAD` si sigue en rama. `--check` no escribe y sale 1 si difiere — es lo que corre el CI |
| `scripts/github-topics-manager.sh` | Pone topics a un repo de GitHub vía `gh api`. `-l` lista repos, `-v <repo>` muestra los topics actuales |
| `scripts/github-topics-manager.README.md` | Manual del anterior: reglas de validación de GitHub y catálogos de topics sugeridos por categoría |
| `CHEAT_CODES.md` | Chuleta personal de ~480 líneas: atajos y aliases de shell, nvim, k8s, terraform, cloud CLIs, seguridad y tmux. Documentación pura, ningún programa la lee |
| `VIM_GUIA.md` | Notas del `vimrc` de respaldo, para cajas sin nvim |

**El nivel de shellcheck del CI deja pasar variables mal escritas.** `ci.yml` y `.githooks/pre-commit` corren `shellcheck -S warning`, y una variable inexistente es SC2153, de nivel *info*. `github-topics-manager.sh` vivió así desde su primer commit: leía `VALID_TOPIPS` donde el array era `VALID_TOPICS`, mandaba `{"names":[""]}` a la API y el CI seguía en verde. Al escribir un script nuevo en `scripts/`, pásale `shellcheck -S info` a mano una vez, o ponle `set -u` para que el fallo aborte en vez de convertirse en una petición mala.

## Key conventions

- **Brewfile/Brewfile.{cloud,k8s,gui} are macOS-only** — never add Linux-specific packages here; add them to the apt block or the binary download section in `install.sh` section 6b. New macOS packages: classify into the right Brewfile split — base for always-needed, `.cloud` for IaC/cloud CLIs, `.k8s` for kubernetes/containers, `.gui` for Mac apps + VSCode extensions.
- **`pinentry-mac` in Security section** — macOS-only, intentional, fine since Brewfile is macOS-only.
- **`~/.zshrc.local`** — for machine-specific config that should not be committed (tokens, host-specific aliases, etc.).
- **Consistent theme** — Catppuccin Mocha across nvim, tmux status bar, starship, and git delta. Keep new UI additions on this theme.
- **`jenv` + `openjdk@17`** — only the pinned version is in Brewfile. Add explicit `openjdk@XX` entries if additional Java versions are needed; do not use the unversioned `openjdk` formula.
- **Nerd Font por plataforma** — macOS/Linux usan **Hack** (`Brewfile` instala `font-hack-nerd-font`); WSL2 usa **JetBrainsMono**, porque ahí renderiza Windows y es lo que instala `install-fonts-windows.ps1`. `wezterm.lua` elige con `font_with_fallback` según `target_triple`; `config/iterm2/dotfiles.json` y la cabecera de `starship.toml` son macOS-only y fijan Hack. Si cambias la fuente de un lado, cambia también el `.ps1` o el Brewfile del otro. Si un terminal muestra `?` en vez de iconos, la causa es siempre la fuente del perfil, no la locale ni `eza`.
- **El perfil de iTerm2 usa el nombre PostScript de la fuente**, no el visible: `"HackNFM-Regular 14"`, no `"Hack Nerd Font Mono 14"`. Con el nombre visible iTerm cae en silencio a la fuente por defecto y vuelven los `?`. Sácalo de la tabla `name` del `.ttf` (record 6), no lo adivines. iTerm tampoco deja marcar un dynamic profile como predeterminado desde el JSON: es un paso manual una vez por máquina.
- **`shellcheck` no vale para zsh** — está instalado (lo usa nvim-lint para `.sh`), pero no soporta zsh. Para `zshrc` y `config/zsh/*.zsh` usa `zsh -n`.
- **Estado leído, nunca hardcodeado** — cualquier comando que reporte estado de una herramienta externa (cuenta de gcloud, contexto de kubectl, etc.) debe leerlo de la herramienta, no repetirlo en un `echo`. Los aliases de GCP se desincronizaron precisamente así; ver la sección `gcx`.
- **Para saber si una herramienta está instalada, pregúntaselo a una zsh de login** — `zsh -lic 'command -v X'`, no un `command -v X` suelto. Las tool calls de agente corren sobre un snapshot de shell que no reproduce el PATH de `zshrc`: le falta el `sbin` de Homebrew, así que `mtr` —que vive en `/usr/local/sbin`— parece ausente cuando está perfectamente instalado. Un inventario hecho desde el snapshot reporta falsos ausentes y lleva a "arreglar" lo que no está roto.
