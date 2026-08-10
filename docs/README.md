# `docs/` — índice

Diez documentos, ~7.900 líneas. Este índice existe para que no tengas que abrir
un plan de 3.284 líneas para averiguar de qué iba.

**Todo lo que hay aquí es histórico.** Son diseños y planes de trabajos que
ya están en `main`: describen el repo en el momento en que se escribieron, no el
de hoy. Sirven para responder *por qué se decidió algo*; para saber *cómo está
el código ahora*, la fuente es `CLAUDE.md` y el propio código.

Si buscas el borrador de trabajo de una sesión de agente, no está aquí: vive en
`.superpowers/sdd/`, que no se versiona. Son dos sitios distintos con el mismo
nombre y confundirlos es fácil.

## `specs/` — diseños aprobados

Uno por trabajo, `AAAA-MM-DD-<tema>-design.md`. Son los que citan los trailers
`Spec:` de los commits y las cabeceras de los hooks, **así que sus rutas no se
mueven ni se renombran**: un trailer roto no lo detecta ningún test.

| Archivo | El problema que resolvía | Dónde está vivo hoy |
|---|---|---|
| `2026-08-07-gcp-switcher-design.md` | Cuatro aliases de GCP en `zshrc` imprimían con `echo` una cuenta hardcodeada que ya no coincidía con la config que activaban | `config/zsh/gcp.zsh`, sección **gcx** de `CLAUDE.md` |
| `2026-08-08-arnes-trazabilidad-design.md` | El repo tenía medio arnés sin saberlo: CI y convención de commits de facto, pero nada que los hiciera cumplir | `.githooks/`, sección **Flujo de trabajo** de `CLAUDE.md` |
| `2026-08-08-ruff-design.md` | `Error running flake8: ENOENT` al abrir cualquier `.py`: un linter declarado en nvim que ningún instalador instalaba | `config/nvim/lua/plugins/lsp.lua`, `Brewfile`, `lib/binaries.sh` |
| `2026-08-09-preset-agent-design.md` | Los cuatro presets asumían una persona delante de una terminal: en una caja de agente casi toda la instalación se gastaba en configs que una zsh no interactiva nunca lee | `install.sh`, `lib/symlinks.sh`, `lib/packages.sh`, sección **`--agent`** de `CLAUDE.md` |
| `2026-08-09-web-escaparate-design.md` | El repo solo se explica en 554 líneas de README: nada que enseñe cómo se ve el entorno ni que deje navegar las ~130 herramientas repartidas entre cuatro Brewfiles y dos ficheros de `lib/` | `web/`, sección **`web/`** de `CLAUDE.md` |

## `plans/` — implementación de esos diseños

Mismo prefijo de fecha que su spec. Los cuatro están **completados y en `main`**;
cada uno lo dice en un banner en su primera línea, con el PR o el rango de
commits donde aterrizó. No son listas de tareas pendientes.

| Archivo | Líneas | Spec | Aterrizó en |
|---|---|---|---|
| `2026-08-07-gcp-switcher.md` | 862 | gcp-switcher | `d048f4a..de33b90`, sin PR (anterior a la protección de rama) |
| `2026-08-08-arnes-trazabilidad.md` | 1873 | arnes-trazabilidad | PR #6, que se estrenó a sí mismo |
| `2026-08-08-ruff.md` | 445 | ruff | PR #11, endurecido después en #15 y #16 |
| `2026-08-09-web-escaparate.md` | 3284 | web-escaparate | PR #37 |

## `reports/` — trabajos que no dejaron código

| Archivo | Qué fue |
|---|---|
| `2026-06-02-github-repository-management.md` | Inventario y limpieza de los 28 repos de GitHub del usuario: clasificación por actividad, borrado de obsoletos y activación de Dependabot. Nada de esto toca estos dotfiles; el script relacionado es `scripts/github-topics-manager.sh` |

## Al añadir un documento

Añádelo también a la tabla que le toque. Un índice desactualizado es peor que
ninguno, y en este repo hay precedente: es la misma razón por la que los mensajes
de estado leen de la herramienta en vez de repetir un `echo`.

Cuando un plan se complete, ponle el banner de estado en la primera línea
—`> **Estado: COMPLETADO.**` más el PR— igual que los tres de arriba. Es lo que
distingue historia de trabajo pendiente para quien lo abra dentro de un año.
