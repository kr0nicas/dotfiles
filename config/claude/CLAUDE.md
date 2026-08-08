# CLAUDE.md — entorno de Jorge Ochoa (kr0nicas)

Utilidades propias de estas máquinas. Las herramientas estándar (rg, fd, bat,
eza, jq, delta…) no se listan a propósito: ya las conoces y ocuparían contexto
en cada sesión de cada proyecto.

## Comandos propios

| Comando | Qué hace |
|---|---|
| `gcx` | Switcher de cuentas y proyectos de GCP con pickers `fzf`. `gcx p` (proyectos de la cuenta activa, `-r` refresca la caché), `gcx use <config>`, `gcx who`. Referencia completa y en vivo: `gcx -h`. **No se llama `gcp`**: ese es el `cp` de coreutils. |
| `t` | Sessionizer de tmux: picker `fzf` sobre `~/projects` y `~/go/src`; crea la sesión o reattachea si ya existe. |
| `sp` / `ssh-pick` | Picker `fzf` de los hosts de `~/.ssh/config` y conecta. |
| `cn` | Wrapper de `@continuedev/cli`; localiza node vía fnm sin necesitar una shell cargada. |
| `dots` | Guarda cambios de `~/dotfiles` con el flujo rama + PR. **Lee el aviso de abajo antes de invocarlo desde una tool call.** |

## Reglas

- **`shellcheck` no vale para zsh.** Está instalado y sirve para `.sh`, pero no
  soporta zsh. Para `zshrc` y cualquier `*.zsh` usa `zsh -n <archivo>`.
- **Python se gestiona con `uv`**, nunca pip/virtualenv/pyenv: `uv venv`,
  `uv pip install`, `uv tool install`, `uv run`. Linter y formateador: `ruff`.
- **Estado leído, nunca hardcodeado.** Cualquier mensaje que reporte estado de
  una herramienta externa (cuenta de gcloud, contexto de kubectl…) debe leerlo
  de la herramienta en tiempo real, no repetirlo en un `echo`.
- **`rtk`** comprime la salida de comandos antes de que la leas, vía hook
  `PreToolUse`. `RTK_DISABLED=1 <cmd>` para saltárselo; `rtk gain` para el ahorro.

## No invoques `dots` desde una tool call de Bash

La tool Bash **no arranca un zsh interactivo**: carga un snapshot cacheado de
`~/.claude/shell-snapshots/`. Ese snapshot puede traer una versión **vieja** de
`dots` — un alias que hacía `git add . && git commit -m "Update dots: $(date)"
&& git push` directamente sobre `main`. Viola tres reglas del repo a la vez
(rama prohibida, mensaje que el hook `commit-msg` rechaza, y `add`
indiscriminado). Un zsh fresco da la función correcta; el snapshot, el alias.

Corre los comandos canónicos, que es lo que hace la función actual:

```bash
git switch -c <tipo>/<ámbito>-<asunto>          # nunca commitear a main
git add -A && git commit -m '<tipo>(<ámbito>): <asunto>'
./scripts/changelog.sh                          # si existe; SIEMPRE en commit aparte
git push -u origin HEAD && gh pr create --fill
```
