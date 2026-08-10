# Escaparate web del repo — diseño

Fecha: 2026-08-09
Estado: aprobado, sin implementar.

## El problema

El repo se explica hoy en `README.md`: 554 líneas y 30 secciones de markdown.
Sirve para consultar, no para enseñar. Quien llega de fuera —o quien quiera ver
el setup sin clonarlo— no tiene nada que mirar: ni cómo se ve el prompt, ni qué
trae cada preset, ni qué son las ~130 herramientas que el instalador declara
repartidas entre cuatro Brewfiles y dos ficheros de `lib/`.

Falta un **escaparate**: una página que enseñe el entorno y deje navegar el
inventario. No sustituye al README ni a `CLAUDE.md`; ninguno de los dos se
vuelca al sitio.

## Decisiones

| Decisión | Elegido | Por qué |
|---|---|---|
| Objetivo | Escaparate / portfolio | Impacto visual primero; el onboarding ya lo cubre el README |
| Ubicación | `web/` en este repo | El sitio vive al lado de lo que documenta y comparte PRs |
| Despliegue | GitHub Pages, export estático | Gratis y sin cuenta de terceros; un escaparate no necesita servidor |
| Estética | Terminal como pieza, no como piel | El gancho de una TUI con la legibilidad de una landing |
| Navegación | One-pager + `/stack` aparte | El escaparate se lee de un scroll; el catálogo tiene URL y filtros propios |
| Datos del catálogo | Derivados del repo + prosa curada, con guardia | Un catálogo escrito a mano se desincroniza al primer `brew` nuevo |
| Idioma | Solo español | El repo entero lo está; duplicar copy es la misma trampa de deriva |

## Arquitectura

### Stack

Next.js 15 (App Router), TypeScript, Tailwind v4, `output: 'export'`.

El export estático impone tres cosas:

- `basePath: '/dotfiles'` — es una *project page* (`kr0nicas.github.io/dotfiles`),
  no una *user page*. Sin `basePath`, todos los assets dan 404.
- `images: { unoptimized: true }` — no hay servidor que optimice.
- Ninguna ruta de API ni server action. Los filtros del catálogo son
  componentes de cliente.

### Integración en el repo

Cuatro cambios fuera de `web/`, ninguno opcional:

- **`.githooks/scopes.txt` gana el ámbito `web`.** Sin él ningún commit del
  sitio pasa `commit-msg`.
- **`.gitignore` gana `web/node_modules/`, `web/.next/` y `web/out/`.**
- **`CLAUDE.md` y `README.md` documentan la estructura del repo.** Un
  directorio de primer nivel sin declarar ahí repite el fallo del índice
  desactualizado contra el que avisa `docs/README.md`.
- **`.github/workflows/web.yml`**, separado de `ci.yml` (ver Despliegue).

### Pipeline de datos — el catálogo no puede mentir

Es la pieza central del diseño. Aplica al catálogo la misma regla que `gcx`
aplica a los mensajes de estado: **leído de la fuente, nunca hardcodeado**.

Tres piezas:

**1. `web/scripts/extract-tools.mjs`** — parser, sin dependencias externas.

| Fuente | Qué extrae | Plataforma |
|---|---|---|
| `Brewfile`, `.cloud`, `.k8s`, `.gui` | líneas `brew`/`cask`/`vscode`, con la categoría del `# --- X ---` que las precede | macOS |
| `lib/binaries.sh` | entradas `gh_latest_*`: repo de GitHub y nombre del binario. El módulo sale del bloque `if [[ $INSTALL_K8S ]]` / `$INSTALL_CLOUD` que las envuelve | Linux |
| `lib/packages.sh` | el bloque `apt install` | Linux |

Salida: `web/src/data/tools.generated.json`, **versionado**. Versionarlo hace
que el diff de "añadí `brew "duf"`" se vea en la PR y que el build de Pages no
dependa de que el parser corra bien en un runner.

**2. `web/src/data/tools.curated.json`** — escrito a mano, y solo con lo que una
máquina no puede saber: descripción de una línea, categoría de presentación y
URL del proyecto.

La categoría que muestra el sitio es **la curada, no la del Brewfile**. Los
`# --- X ---` solo existen en los Brewfiles, así que no cubren nada de Linux;
sirven para prerrellenar la entrada curada al añadir una herramienta, no como
dato de presentación.

**3. `web/scripts/check-tools.mjs`** — la guardia, en las dos direcciones:

- herramienta extraída del repo sin entrada curada → error;
- entrada curada de algo que el repo ya no instala → error.

Corre en `npm run build` y en CI, con el mismo papel que `changelog.sh --check`.

Nombre, módulo y plataforma nunca se teclean. Solo la prosa.

**Riesgo asumido y su mitigación.** El parser de `lib/binaries.sh` es regex
sobre bash. Si se reescribe la forma de esas arrays, el parser deja de casar —
y "no la veo" no es un error, es un catálogo mutilado publicado en silencio.
Por eso el checker valida además un **conteo mínimo por fuente**: si aparecen 12
binarios donde había 43, el build falla en vez de publicar.

Esos mínimos son constantes declaradas en `check-tools.mjs`, una por fuente. Se
suben al añadir herramientas y **solo se bajan a mano**, en el mismo commit que
retira la herramienta y explicando por qué. Bajarlos para "arreglar" un build
rojo es desactivar la guardia.

## Estructura del sitio

### `/` — one-pager

1. **Hero** — ventana de terminal que se escribe sola (`git clone` →
   `./install.sh`), botón de copiar, badges macOS/Debian. Con
   `prefers-reduced-motion` no anima: pinta el comando completo de golpe.
2. **Highlights** — cinco tarjetas: cross-platform real, cinco presets,
   checksums verificados, arnés de hooks + CI, Catppuccin en todo el stack.
3. **Presets** — selector interactivo. Al elegir `--vps`, `--agent`,
   `--k8s-node`, `--container` o `--minimal` se ve qué módulos y fases enciende
   y cuántas herramientas trae. El recuento sale del catálogo, así que no puede
   desfasarse.
4. **Capturas** — grid dentro de chrome de terminal.
5. **`gcx`** — sección corta con demo del picker; es la pieza propia más
   enseñable del repo.
6. **Teaser del stack** con CTA a `/stack`, y footer con repo, CHANGELOG y
   `docs/`.

### `/stack` — catálogo

Buscador y filtros por plataforma, módulo y categoría sobre el JSON. El estado
va en la querystring (`?m=k8s`) para que sea enlazable; con export estático eso
obliga a envolver `useSearchParams` en `<Suspense>` o el build falla.

### Componentes

Uno por fichero, todos pequeños: `TerminalWindow` (el chrome reutilizable de
hero, presets y capturas), `ToolCard`, `PresetSelector`, `FilterBar`,
`CopyButton`, `SectionHeading`.

### Tema y tipografía

Catppuccin Mocha como variables CSS en `globals.css`, expuestas a Tailwind v4
con `@theme`. Una sola fuente de color para todo el sitio.

La monoespaciada es la del sistema (`ui-monospace`), **no Hack Nerd Font**.
Hack es MIT y podría autoalojarse, pero la variante Nerd pesa varios MB y no
compensa en un sitio estático. Donde haga falta un icono, va un SVG.

### Lo que aporta el humano

Las capturas de nvim, tmux, starship, k9s y `gcx` no las puede generar el
agente. El sitio se entrega con huecos y un `web/public/screenshots/README.md`
que dice cuál falta y a qué tamaño.

## Despliegue

`.github/workflows/web.yml`, separado de `ci.yml` — que es shell puro y no debe
saber de Node.

Dispara en `web/**` **y además** en `Brewfile*`, `lib/binaries.sh` y
`lib/packages.sh`. Así, tocar un Brewfile sin actualizar el catálogo rompe el CI
en la PR, que es el único momento en que sirve enterarse.

- En PR: `npm ci`, `check-tools`, `next build`. No despliega.
- En `main`: lo anterior más `upload-pages-artifact` y `deploy-pages`, con
  `permissions: pages: write, id-token: write` en ese job.

Paso manual, una sola vez y fuera del repo: **Settings → Pages → Source:
GitHub Actions**.

## Pruebas

Siguiendo la cultura del repo (arneses propios, cero frameworks):
`web/scripts/extract-tools.test.mjs` con `node:test`, que viene en Node y no
añade dependencias. Cubre el parser contra fixtures y fija los conteos mínimos
contra los ficheros reales. `check-tools.mjs` es en sí mismo la prueba de
integración.

Nada de Jest, Vitest ni Playwright.

## Fuera de alcance

Deliberadamente no entra: CMS, MDX, blog, i18n, analytics, modo claro (el repo
es Mocha; un toggle es el doble de CSS para nada), volcado del README o de
`CLAUDE.md` al sitio, y búsqueda difusa —un `includes()` sobre 130 elementos
sobra.
