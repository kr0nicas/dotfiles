# Preset `--agent`: provisionar una caja cuyo consumidor es un agente

**Fecha:** 2026-08-09 · **Estado:** aprobado e implementado.

## El problema

`install.sh` tenía cuatro presets (`--vps`, `--container`, `--k8s-node`,
`--minimal`) y los cuatro asumen lo mismo: que al final habrá **una persona**
delante de una terminal. Los cuatro instalan y enlazan zshrc, starship, fzf,
plugins de zsh, tmux, nvim, wezterm y el perfil de iTerm2.

Cuando el consumidor de la caja es un agente de Claude Code, nada de eso se
ejecuta jamás. Verificado, no supuesto:

- La tool Bash de Claude Code es una zsh **no interactiva** que **no sourcea
  `zshrc`**. `gcx` no está definida ahí, aunque `starship` sí aparezca en el
  PATH — porque vive en `/usr/local/bin`, no porque el prompt se renderice.
- Sin sesión interactiva no hay prompt, ni keybindings de fzf, ni
  autosuggestions, ni aliases del zshrc.
- Sin terminal delante no hay tmux, ni nvim, ni wezterm, ni perfil de iTerm2.

Así que en una caja de agente casi todo el tiempo de instalación se gasta en
cosas que nada va a leer. Y el resumen final de `phase_verify` remataba con
`Ejecuta: source ~/.zshrc`, un consejo que en esa caja no significa nada.

## Lo que sí le sirve a un agente

- Los binarios de `lib/binaries.sh` (delta, lazygit, ruff, zoxide, jless, k9s,
  stern, sops, gitleaks…) y **los de `phase_packages`**: `rg`, `fd`, `bat`, `jq`,
  `yq`, `unzip` y `zstd` salen de ahí, no de `binaries.sh`.
- `uv`, `fnm` + Node y `ruff` de `phase_runtimes`.
- Los hooks de git de `phase_repo`: el arnés del repo aplica igual —o más— a un
  agente que a una persona.
- Los symlinks de `~/.claude/`: `settings.json` (con el hook de rtk),
  `statusline.sh` y el `CLAUDE.md` global.

## Alcance

`--agent` = `phase_detect` + `phase_packages` (degradando, ver abajo) +
`phase_runtimes` + `phase_binaries` + solo el bloque de symlinks de `~/.claude/`
+ `phase_repo` + `phase_verify`.

No corre `phase_editors` (tmux/TPM, Neovim, Claude Code) y no enlaza `zshrc`,
`tmux.conf`, `.gitconfig`, `starship.toml`, `vimrc`, `ssh/colors.conf`, rtk,
wezterm, iTerm2, direnv ni `config/nvim`.

`--agent` **no toca `INSTALL_CLOUD` ni `INSTALL_K8S`**: son ortogonales a quién
usa la caja —un agente puede necesitar `kubectl` igual que una persona— y siguen
componiéndose (`--agent --no-k8s`). Sí apaga `INSTALL_GUI`: en una caja sin
pantalla, VSCode y Brave no los abre nadie.

### Consecuencias asumidas

- **No instala Claude Code.** Vive en `phase_editors`, junto a tmux y nvim, y
  partir esa fase no entraba en el alcance. No duele: en una caja de agente
  `claude` ya está por construcción — es lo que está corriendo.
- **En macOS el `Brewfile` base sigue trayendo tmux, nvim y fonts.** El preset
  salta fases y symlinks, no fórmulas: dividir el `Brewfile` base por
  interactividad es otro trabajo.
- **`phase_verify` sí corre**, aunque no estuviera en la lista original. Un
  preset sin resumen final sería una regresión; lo que se adapta es su
  contenido: las filas de `tpm` y `lazy.nvim` se omiten (con `--agent` serían un
  ❌ permanente por diseño, y un ❌ que sale siempre entrena a ignorar el resumen
  entero) y el consejo final pasa a ser el que importa aquí — que `~/.local/bin`
  esté en el PATH del proceso del agente.

## El trabajo real: partir `phase_symlinks`

`phase_symlinks` era todo-o-nada: 160 líneas en una sola función. Pedir "solo el
bloque de `~/.claude/`" obligaba a duplicarlo.

Queda partido en **un grupo por destino** (`symlinks_shell`, `symlinks_ssh`,
`symlinks_claude`, `symlinks_rtk`, `symlinks_wezterm`, `symlinks_iterm2`,
`symlinks_direnv`, `symlinks_nvim`), con `safe_link`/`safe_mkdir` subidos a nivel
de archivo porque ahora los comparten todos. `phase_symlinks` y
`phase_symlinks_agent` no hacen más que elegir qué grupos llamar.

El modo de fallo de este refactor es un **grupo huérfano**: definido y nunca
llamado no rompe nada visible, solo deja de enlazar en silencio. De ahí que
`lib/symlinks.test.sh` derive la lista de grupos del propio archivo con un `grep`
y compruebe que `phase_symlinks` llama a todos, además de comparar su salida
completa contra la concatenación de los grupos.

## Decisión: qué hace `--agent` con `phase_packages`

**Decisión: incluirla, degradando cuando no se puede elevar.**

El bloque de Debian es todo `sudo apt`, y su primera línea —`sudo apt update`—
no lleva `|| true`: en un sandbox sin root muere ahí y se lleva por delante el
instalador entero bajo `set -e`. Eso invitaba a omitirla del preset.

Omitirla es peor, y por una razón concreta que hay que mirar en el código antes
de opinar: **`rg`, `fd`, `bat`, `jq`, `yq`, `unzip` y `zstd` no están en
`lib/binaries.sh`**. Salen de `phase_packages` (apt en Linux, Brewfile en macOS).
Son, además, las herramientas que un agente usa más. Y en **macOS** la fase es
`brew bundle`, que no necesita sudo y es la **única** fuente de binarios del repo
(`phase_binaries` es solo Linux): omitirla ahí dejaría la caja casi vacía.
`unzip` remata el argumento: sin él, `jless`, `lnav` y `tflint` se saltan en la
fase siguiente.

La forma es `phase_packages_if_possible`, en `lib/packages.sh`, que corre
`phase_packages` si —y solo si— tiene sentido:

- **macOS**: siempre. Es brew, no usa sudo.
- **`--dry-run`**: siempre. La fase ya no instala nada, y saltarla haría que la
  salida de `--dry-run --agent` dependiera de si esta máquina tiene sudo. El
  oráculo del repo dejaría de ser determinista, que es un precio inaceptable.
- **Linux**: si `packages_can_elevate`, que es `root`, o `sudo -n true`.
  `sudo -n` y no `command -v sudo` porque lo que importa no es que sudo exista
  sino que **conteste sin pedir contraseña**: una caja de agente no tiene a quién
  preguntársela, y un sudo que prompt-ea no falla, se **cuelga**.

Cuando no se puede, no aborta: avisa y **enumera lo que debe traer la imagen
base** (`jq yq ripgrep fd-find bat eza unzip zstd age direnv btop gh`, además de
`curl git zsh` que ya exige `phase_detect`). Es el mismo reparto que hace el job
`install-smoke` de `ci.yml`, que instala los prerrequisitos a mano antes de
llamar a `install.sh`.

`phase_packages` **no se toca**. Hacer que su `apt update` degradara habría
cambiado el comportamiento de `--vps` y `--k8s-node`, donde un apt roto debe
seguir siendo ruidoso.

## Verificación

- `./install.sh --dry-run` con `--vps`, `--container`, `--k8s-node`, `--minimal`
  y sin flags, capturado antes y después: **salida idéntica byte a byte**. Es el
  oráculo que prueba que partir `phase_symlinks` no cambió comportamiento.
- `./install.sh --dry-run --agent` en macOS y en `debian:stable-slim`: las fases
  y los tres symlinks acordados, ni uno más.
- Siete suites, 178 tests. Las nuevas: 27 en `lib/symlinks.test.sh` (grupos,
  variante de agente, guarda de grupo huérfano) y 10 añadidos a
  `lib/packages.test.sh` (`packages_can_elevate` y la decisión de
  `phase_packages_if_possible`, con `id`/`sudo`/`phase_packages` sombreados por
  funciones del mismo nombre, sin sistema delante).
- `shellcheck -x -S info` sobre `install.sh` y las dos suites de `lib/`.
