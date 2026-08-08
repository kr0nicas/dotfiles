# Arnés de reglas y trazabilidad

Fecha: 2026-08-08
Estado: diseño aprobado

## Problema

El repo ya tiene la mitad del arnés y no lo sabe. Hay CI (`.github/workflows/ci.yml`)
que corre `zsh -n`, `bash -n`, `shellcheck -x -S warning` y la suite de 45 tests de
`gcx`. Hay dependabot. Hay `docs/superpowers/{specs,plans}` con el spec y el plan de
`gcx`. Y los últimos 24 commits siguen Conventional Commits en español de forma
notablemente consistente.

Lo que falta es que nada de eso sea **exigible**. Cuatro huecos concretos:

**Nadie valida el mensaje de commit.** La convención vive en la costumbre. El único
commit reciente que la rompe lo genera el propio repo: el alias `dots`
(`zshrc`) hace `git add . && commit "Update dots: $(date)"`, que produjo
`c2f35e7 Update dots: 2026-07-24`. La herramienta de guardar rápido es la que
contamina el historial.

**No hay hooks locales.** `core.hooksPath` está sin configurar y `.git/hooks` solo
tiene samples. Un `shellcheck` roto se descubre en CI, minutos después del push, con
el commit ya escrito.

**No hay trazabilidad hacia atrás.** `CLAUDE.md` funciona de facto como bitácora de
decisiones —la trampa de `gcloud config configurations list`, por qué `gcx` y no
`gcp`— pero responde "cómo es esto hoy", no "qué cambió y cuándo". Para lo segundo
solo está `git log` en crudo, sin agrupar y sin enlace al spec que originó el cambio.

**Nada impide commitear directo a `main`.** `main` no está protegido en GitHub y el
flujo real de las últimas sesiones ha sido trabajar directamente sobre él. Hay 4 ramas
remotas obsoletas (cada una 1 commit adelante, ~31 detrás) y 4 worktrees de sesiones
anteriores, 3 en detached HEAD, como sedimento de no tener flujo.

## Objetivos

1. Poder responder "¿por qué está esto así?" meses después, desde el archivo hasta la
   razón.
2. Que no se cuele nada roto ni mal etiquetado, con feedback en segundos y no en CI.
3. Que el trabajo entre a `main` por rama y PR, nunca directo.
4. Que Claude commitee cada feature al cerrarla, sin que haya que pedírselo.

## No objetivos

- **Versionado semántico ni releases.** Son dotfiles, no una librería: no hay
  consumidores a los que prometer compatibilidad. Sin tags, sin `v1.2.3`.
- **ADRs en `docs/decisions/`.** Se solapan con lo que `CLAUDE.md` ya hace bien y
  añaden ceremonia a cada cambio pequeño.
- **Plantillas de issue.** Repo de un solo mantenedor.
- **Revisión por terceros.** El PR es el sitio donde CI bloquea y donde queda el
  contexto, no un trámite de aprobación.

## Diseño

### 1. La regla: qué es un commit válido

```
<tipo>(<ámbito>): <asunto>

<cuerpo: el porqué, no el qué — el diff ya dice el qué>

Spec: docs/superpowers/specs/<archivo>.md
Refs: #12
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

| Elemento | Regla |
|---|---|
| Tipo | `feat`, `fix`, `docs`, `refactor`, `chore`, `ci`, `test`, `perf`, `build`, `revert` |
| Ámbito | Opcional. Si va, se valida contra `.githooks/scopes.txt` |
| Asunto | Minúscula inicial, imperativo, sin punto final, ≤72 caracteres |
| Cuerpo | Opcional, separado por línea en blanco |
| Trailers | `Spec:`, `Refs:`, `Co-Authored-By:` |

El ámbito se valida contra una lista cerrada precisamente para que `gcp` y `gcloud` no
acaben conviviendo como dos ámbitos distintos. El mensaje de error indica el archivo
donde añadir uno nuevo, para que ampliar la lista cueste menos que saltarse la regla.

Se saltan la validación: merge commits, reverts generados por git, y `fixup!`/`squash!`.

### 2. `.githooks/` — tres puertas

| Hook | Qué corre | Coste |
|---|---|---|
| `commit-msg` | La regla de arriba | ~10 ms |
| `pre-commit` | Lint de lo staged + barrido de secretos | ~0.3 s |
| `pre-push` | Suite `gcx` completa + guardia de `main` | ~2 s |

`pre-commit` despacha por extensión sobre el índice, no sobre el repo entero:

| Patrón staged | Comprobación |
|---|---|
| `install.sh`, `lib/*.sh`, `scripts/*.sh` | `shellcheck -x -S warning install.sh` |
| `zshrc`, `config/zsh/*.zsh` | `zsh -n` |
| `*.json` | `python3 -m json.tool` |
| `*.lua` | `luajit -bl … /dev/null` |

El barrido de secretos bloquea nombres (`id_rsa`, `*.pem`, `*.key`, `.env`) y
contenido (`gho_`, `ghp_`, `AKIA`, `-----BEGIN * PRIVATE KEY-----`).

**Degradación deliberada**: si falta la herramienta (`shellcheck` en un VPS mínimo,
`luajit` en un contenedor), el hook **avisa y deja pasar**. Estos dotfiles se clonan en
cajas sin nada; un hook que exige herramientas rompería el arranque, que es justo el
caso de uso del repo. Lo que **nunca** degrada es `commit-msg` ni el barrido de
secretos: ambos solo necesitan bash.

`.githooks/lib.sh` concentra colores y helpers compartidos, mismo patrón que `lib/`.

### 3. Activación

Fase nueva `lib/repo.sh` → `phase_repo`, invocada desde `install.sh`:

```bash
git config core.hooksPath .githooks
```

Respeta `--dry-run` como el resto de fases. Tiene que estar en el instalador y no solo
documentado porque `core.hooksPath` es configuración local del clon: no viaja en el
repo, así que sin esta fase los hooks existen pero no se ejecutan en ninguna máquina
nueva.

### 4. Flujo de trabajo

```bash
git switch -c feat/iterm2-perfil
# …commits pequeños y válidos…
git push -u origin feat/iterm2-perfil
gh pr create --fill
gh pr merge --merge --delete-branch
```

Nombre de rama derivado del commit: `feat(iterm2): perfil dinámico` →
`feat/iterm2-perfil-dinamico`.

**`dots` pasa de alias a función.** Hoy hace `git add . && commit "Update dots: fecha"
&& push` sobre `main`, que bajo las reglas nuevas falla en tres sitios a la vez: rama
prohibida, mensaje inválido y `git add .` indiscriminado. El comportamiento nuevo:

```zsh
dots 'fix(zshrc): quitar alias que rompía du'
```

Desde `main` deriva la rama del mensaje, commitea, empuja y abre el PR. Desde una rama
solo commitea y empuja. Sin mensaje, error explicando el formato. Ninguna fecha
autogenerada.

### 5. CHANGELOG generado

`scripts/changelog.sh` regenera `CHANGELOG.md` **entero** desde el historial. Es un
archivo generado; editarlo a mano no tiene sentido y el CI lo detecta.

La unidad de agrupación es la **feature**, y se resuelve de dos formas según dónde
esté:

- **Ya en `main`**: `git log --first-parent` da los merge commits; dentro de cada uno,
  `<merge>^1..<merge>^2` lista los commits reales de la feature.
- **Todavía en la rama**: los commits de `main..HEAD`, bajo un encabezado derivado del
  nombre de la rama y del `Refs: #N` si ya hay PR abierto.

Esa agrupación es exactamente lo que `--no-ff` hace posible; con squash no existiría.

Los dos caminos tienen que producir el **mismo encabezado** antes y después del merge,
o el archivo cambiaría solo por mergear. Por eso el merge commit se crea con el número
de PR y el nombre de rama en el asunto (`gh pr merge --merge` lo hace por defecto), y
el script extrae de ahí la misma clave que usó en la rama.

```markdown
## 2026-08-08 · #13 Perfil de iTerm2 y fuente por SO

### Features
- **iterm2**: perfil dinámico SRE 2026 (`a1b2c3d`)
- **wezterm**: fuente Nerd por `target_triple` (`c4b5a61`)

### Fixes
- **starship**: sustitución de dotfiles con `truncate_to_repo` (`7d8e9f0`)
```

Los commits directos sobre `main` anteriores al arnés se listan como entradas sueltas,
sin PR asociado.

Al ser 100% generado, CI lo regenera en cada PR y **falla si difiere** del commiteado.
Sin criterio subjetivo: si falla, se corre el script. Regenerarlo es por tanto el
último paso antes del push final de un PR, y la plantilla lo recoge en su checklist.

### 6. Plantilla de PR y CI

`.github/pull_request_template.md` pide qué cambia, por qué, **cómo se verificó**
—comandos y salida real, no "probado"— y una checklist que incluye el `--dry-run` de
`install.sh` cuando se toca el instalador.

Al `ci.yml` existente se le añaden dos jobs nuevos y se amplía el que ya hay:

- `commit-lint` (nuevo) — recorre los commits del rango
  `origin/main..HEAD` y pasa cada mensaje por `.githooks/commit-msg`, de modo que la
  lógica sea literalmente la misma en local y en CI. Requiere `fetch-depth: 0`.
- `changelog-drift` (nuevo) — corre `scripts/changelog.sh` y falla si
  `git diff --exit-code CHANGELOG.md` detecta cambios.
- `lint-and-test` (existente) — se le añade `.githooks/hooks.test.sh` junto a la suite
  de `gcx`.

### 7. Protección de `main`

```
required_status_checks        : strict, contexto "Lint y tests"
required_pull_request_reviews : 0 aprobaciones   ← exige PR, no exige revisor
enforce_admins                : false            ← romper el cristal es posible
allow_force_pushes            : false
allow_deletions               : false
required_linear_history       : false            ← porque usamos --no-ff
```

`required_approving_review_count: 0` es lo que hace que un repo de un solo mantenedor
pueda exigir PR sin quedar bloqueado esperando un revisor que no existe.

`enforce_admins: false` es deliberado: a las 3am arreglando un VPS hay que poder
saltárselo. Queda en el audit log de GitHub, que es la trazabilidad que se pide.

### 8. La regla de comportamiento

Sección nueva en `CLAUDE.md` con el flujo obligatorio: rama antes de tocar código,
commit al cerrar cada unidad de trabajo, PR al terminar, nunca push a `main`.

Es la pieza más importante para el objetivo 4 y la que no requiere infraestructura.
Sin ella las otras siete secciones son andamiaje que Claude puede ignorar; con ella es
lo primero que lee en cada sesión.

### 9. Tests del arnés

`.githooks/hooks.test.sh`, mismo patrón que `config/zsh/gcp.test.zsh`: arnés propio con
`assert_eq`/`assert_contains`, sin dependencias externas.

Cubre mensajes válidos e inválidos (tipo desconocido, ámbito fuera de lista, asunto en
mayúscula, asunto largo, punto final), las exenciones (merge, revert, fixup), el
barrido de secretos, y —lo que más importa— que **degrada** cuando falta `shellcheck`.
Un hook sin tests es un hook que un día bloquea todo y nadie sabe por qué.

## Componentes

| Archivo | Responsabilidad |
|---|---|
| `.githooks/lib.sh` | Colores, `has()`, helpers compartidos |
| `.githooks/commit-msg` | Valida formato, tipo, ámbito, longitud |
| `.githooks/pre-commit` | Lint de lo staged + barrido de secretos |
| `.githooks/pre-push` | Suite completa + guardia de `main` |
| `.githooks/scopes.txt` | Lista cerrada de ámbitos válidos |
| `.githooks/hooks.test.sh` | Suite del arnés |
| `lib/repo.sh` | `phase_repo` — activa `core.hooksPath` |
| `scripts/changelog.sh` | Genera `CHANGELOG.md` desde el historial |
| `.github/pull_request_template.md` | Plantilla de PR |
| `CHANGELOG.md` | Generado, no editar a mano |

## Manejo de errores

| Situación | Comportamiento |
|---|---|
| Mensaje inválido | Bloquea. Error señala qué regla falló y muestra un ejemplo válido |
| Ámbito desconocido | Bloquea. Lista los válidos e indica `.githooks/scopes.txt` |
| Falta `shellcheck`/`luajit` | Avisa y deja pasar |
| Falta `python3` para JSON | Avisa y deja pasar |
| Secreto detectado | Bloquea. No degrada nunca |
| Push a `main` | Bloquea con instrucción de crear rama |
| Suite `gcx` falla en pre-push | Bloquea |
| Emergencia | `--no-verify` en local; admin bypass en GitHub |

El bypass es explícito y deja rastro por diseño. Un arnés sin salida de emergencia se
desactiva entero el primer día que estorba.

## Plan de migración

1. **PR con lo pendiente** — rama `feat/terminal-iterm2-fuentes`, 4 commits ya hechos
   (`feat(iterm2)`, `feat(wezterm)`, `fix(starship)`, `docs`). Deja el working tree
   limpio antes de tocar nada más.
2. **PR del arnés** — rama `chore/arnes-trazabilidad`. Se estrena a sí mismo.
3. **Protección de `main`** una vez el arnés está dentro, con confirmación explícita
   por ser una acción sobre un repo público.
4. **Limpieza** — 3 worktrees en detached HEAD y el PR abierto de dependabot
   (`actions/checkout` 5→7).

Las 4 ramas remotas obsoletas **no se borran a ciegas**: cada una tiene 1 commit que no
está en `main`. Se inspecciona qué contienen y se reporta antes de borrar nada.

## Criterios de éxito

- Un commit con mensaje inválido no llega a existir.
- Un `.pem` o una clave privada no llegan a stagearse.
- `git push origin main` es rechazado por GitHub, no solo desaconsejado.
- Dado un archivo raro, `git log --first-parent` + `CHANGELOG.md` + el trailer `Spec:`
  llevan hasta la razón sin depender de la memoria de nadie.
- La suite del arnés pasa en un contenedor sin `shellcheck`, sin `luajit` y sin
  `gcloud`, igual que la de `gcx`.
