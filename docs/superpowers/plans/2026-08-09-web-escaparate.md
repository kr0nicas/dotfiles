# Escaparate web — plan de implementación

> **Para agentes:** SUB-SKILL OBLIGATORIA: usa `superpowers:subagent-driven-development` (recomendada) o `superpowers:executing-plans` para ejecutar este plan tarea a tarea. Los pasos usan casillas (`- [ ]`) para seguimiento.

**Objetivo:** publicar en GitHub Pages un escaparate del repo cuyo catálogo de herramientas se deriva de los ficheros declarativos del propio repo, con una guardia que rompe el CI si se desincroniza.

**Arquitectura:** Next.js 15 con `output: 'export'` en `web/`. Un extractor sin dependencias parsea `Brewfile*`, `lib/binaries.sh`, `lib/packages.sh` e `install.sh` y escribe `tools.generated.json` versionado; un fichero curado a mano aporta solo prosa; un checker compara ambos en las dos direcciones y falla el build si no cuadran. El sitio consume la unión de los dos JSON.

**Stack:** Next.js 15 (App Router), TypeScript, Tailwind v4, `node:test`. Cero dependencias de runtime más allá de React/Next.

**Spec:** `docs/superpowers/specs/2026-08-09-web-escaparate-design.md`

## Restricciones globales

- **Idioma del sitio: solo español.** Todo el copy visible, en español.
- **Tema: Catppuccin Mocha, sin modo claro.** Definido una sola vez en `web/src/app/globals.css` con `@theme`. Ningún componente escribe un hex a pelo.
- **Monoespaciada: la del sistema** (`ui-monospace, SFMono-Regular, Menlo, monospace`). Prohibido autoalojar Hack Nerd Font.
- **`basePath: '/dotfiles'`** e **`images.unoptimized: true`** — obligatorios con `output: 'export'` en una *project page*.
- **Nombre, módulo y plataforma de una herramienta jamás se escriben a mano.** Solo salen del extractor. A mano va únicamente `nombre` de presentación, `categoria`, `descripcion` y `url`.
- **Ámbito de commit `web`** para todo lo que toque `web/`; `ci` para el workflow; `docs` para documentación. Los tipos y ámbitos válidos los valida `.githooks/commit-msg` contra `.githooks/scopes.txt`.
- **Nunca encadenes comandos detrás de un `git commit`.** Commitea aislado y comprueba con `git log --oneline -1`.
- **Node ≥ 20.11** (se usa `import.meta.dirname`).
- Todos los comandos `npm` se ejecutan **desde `web/`**.

## Estructura de ficheros

| Fichero | Responsabilidad |
|---|---|
| `web/package.json` | Scripts y dependencias |
| `web/next.config.mjs` | `output: 'export'`, `basePath`, `images.unoptimized` |
| `web/postcss.config.mjs` | Tailwind v4 |
| `web/tsconfig.json` | TS + alias `@/*` |
| `web/src/app/globals.css` | Tokens Catppuccin vía `@theme` |
| `web/src/app/layout.tsx` | Shell HTML, metadatos, `lang="es"` |
| `web/src/app/page.tsx` | One-pager |
| `web/src/app/stack/page.tsx` | Catálogo |
| `web/src/data/types.ts` | Tipos compartidos del modelo de datos |
| `web/src/data/tools.generated.json` | **Generado**, versionado |
| `web/src/data/tools.curated.json` | Prosa a mano |
| `web/src/data/herramientas.ts` | Une generado + curado; API que consume la UI |
| `web/scripts/extract-brew.mjs` | Parser de `Brewfile*` |
| `web/scripts/extract-binaries.mjs` | Parser de `lib/binaries.sh` |
| `web/scripts/extract-apt.mjs` | Parser del bloque apt de `lib/packages.sh` |
| `web/scripts/extract-presets.mjs` | Parser de los flags de `install.sh` |
| `web/scripts/extract-tools.mjs` | Orquestador: escribe `tools.generated.json` |
| `web/scripts/extract-real.test.mjs` | Regresión de los extractores contra los ficheros reales |
| `web/scripts/check-tools.mjs` | Guardia bidireccional + conteos mínimos |
| `web/src/components/*.tsx` | Un componente por fichero |
| `.github/workflows/web.yml` | Build, guardia y deploy a Pages |

---

### Task 1: Andamiaje de `web/` e integración con el repo

**Ficheros:**
- Crear: `web/package.json`, `web/next.config.mjs`, `web/postcss.config.mjs`, `web/tsconfig.json`, `web/next-env.d.ts`, `web/public/.nojekyll`, `web/src/app/globals.css`, `web/src/app/layout.tsx`, `web/src/app/page.tsx`
- Modificar: `.githooks/scopes.txt`, `.gitignore`

**Interfaces:**
- Consume: nada.
- Produce: proyecto Next que compila a `web/out/`; clases Tailwind de tema (`bg-base`, `text-text`, `text-lavender`, `border-surface0`…) que usan todas las tareas de UI.

- [ ] **Paso 1: Añadir el ámbito `web` a los hooks**

Sin esto, ningún commit de esta tarea pasa `commit-msg`. En `.githooks/scopes.txt`, bajo la sección `# Infraestructura del repo`, tras la línea `scripts`:

```
scripts
web
```

- [ ] **Paso 2: Ignorar los artefactos de Node**

Añadir al final de `.gitignore`:

```gitignore

# Escaparate web (web/): artefactos de build, nunca al repo.
# tools.generated.json NO va aquí: se versiona a propósito, para que el diff de
# "añadí un brew" se vea en la PR y el deploy no dependa del parser.
web/node_modules/
web/.next/
web/out/
```

- [ ] **Paso 3: Crear `web/package.json`**

`build` corre la guardia **antes** que `next build`: si el JSON versionado está rancio, no se publica.

```json
{
  "name": "dotfiles-web",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "next dev",
    "build": "node scripts/check-tools.mjs && next build",
    "extract": "node scripts/extract-tools.mjs",
    "check": "node scripts/check-tools.mjs",
    "test": "node --test scripts/"
  },
  "dependencies": {
    "next": "^15.1.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@tailwindcss/postcss": "^4.0.0",
    "@types/node": "^22.10.0",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "tailwindcss": "^4.0.0",
    "typescript": "^5.7.0"
  }
}
```

- [ ] **Paso 4: Crear `web/next.config.mjs`**

```js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // Pages sirve el sitio bajo /dotfiles (project page, no user page).
  // Sin basePath, todos los assets dan 404 en producción y ninguno en local.
  output: 'export',
  basePath: '/dotfiles',
  images: { unoptimized: true },
  trailingSlash: true,
}

export default nextConfig
```

- [ ] **Paso 5: Crear `web/postcss.config.mjs` y `web/tsconfig.json`**

`web/postcss.config.mjs`:

```js
export default {
  plugins: { '@tailwindcss/postcss': {} },
}
```

`web/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

`web/next-env.d.ts`:

```ts
/// <reference types="next" />
/// <reference types="next/image-types/global" />
```

`web/public/.nojekyll`: fichero vacío.

- [ ] **Paso 6: Crear `web/src/app/globals.css` con el tema**

Única fuente de color del sitio. Los nombres son los de Catppuccin Mocha; Tailwind v4 genera `bg-*`, `text-*` y `border-*` a partir de `--color-*`.

```css
@import "tailwindcss";

@theme {
  --color-base: #1e1e2e;
  --color-mantle: #181825;
  --color-crust: #11111b;
  --color-surface0: #313244;
  --color-surface1: #45475a;
  --color-surface2: #585b70;
  --color-overlay0: #6c7086;
  --color-subtext0: #a6adc8;
  --color-subtext1: #bac2de;
  --color-text: #cdd6f4;
  --color-blue: #89b4fa;
  --color-lavender: #b4befe;
  --color-sapphire: #74c7ec;
  --color-teal: #94e2d5;
  --color-green: #a6e3a1;
  --color-yellow: #f9e2af;
  --color-peach: #fab387;
  --color-maroon: #eba0ac;
  --color-red: #f38ba8;
  --color-mauve: #cba6f7;
  --color-pink: #f5c2e7;

  --font-mono: ui-monospace, SFMono-Regular, Menlo, monospace;
}

html {
  scroll-behavior: smooth;
}

@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

- [ ] **Paso 7: Crear `layout.tsx` y una `page.tsx` mínima**

`web/src/app/layout.tsx`:

```tsx
import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Dotfiles SRE 2026 — Jorge Ochoa',
  description:
    'Entorno SRE reproducible para macOS y Debian: un comando, cinco presets, más de 130 herramientas con checksums verificados.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className="bg-base text-text antialiased">{children}</body>
    </html>
  )
}
```

`web/src/app/page.tsx` (provisional, se sustituye en la Task 7):

```tsx
export default function Home() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-24">
      <h1 className="text-4xl font-bold tracking-tight">Dotfiles SRE 2026</h1>
      <p className="mt-4 text-subtext0">Andamiaje en pie.</p>
    </main>
  )
}
```

- [ ] **Paso 8: Instalar y comprobar que compila**

```bash
cd web && npm install && npx next build
```

Esperado: termina en `Exporting (3/3)` y existe `web/out/index.html`. Compruébalo:

```bash
ls web/out/index.html && grep -c '/dotfiles/_next' web/out/index.html
```

Esperado: la ruta existe y el `grep` devuelve un número ≥ 1 — confirma que `basePath` se aplicó.

> Nota: `npm run build` fallará todavía porque `check-tools.mjs` no existe. Es correcto: se usa `npx next build` hasta la Task 6.

- [ ] **Paso 9: Commit**

```bash
git add .gitignore .githooks/scopes.txt web/
git commit -m 'feat(web): andamiar el escaparate con Next.js y Tailwind

basePath e images.unoptimized no son preferencias: con output export en una
project page, sin ellos todos los assets dan 404 en produccion y ninguno en
local, que es la peor forma de descubrirlo.

El ambito web se anade a scopes.txt en este mismo commit porque sin el
commit-msg rechaza todo lo que venga despues.'
```

Comprueba que existe antes de seguir: `git log --oneline -1`.

---

### Task 2: Extractor de `Brewfile*`

**Ficheros:**
- Crear: `web/scripts/extract-brew.mjs`, `web/scripts/extract-brew.test.mjs`
- Crear: `web/src/data/types.ts`

**Interfaces:**
- Consume: nada.
- Produce: `extraerBrew(rutaRepo: string): Entrada[]`. `Entrada` es el tipo que emiten los cuatro extractores y que consume `extract-tools.mjs`:

```ts
type Entrada = {
  clave: string        // `${tipo}:${nombre}`, único en todo el catálogo
  nombre: string       // nombre crudo tal y como lo declara el repo
  tipo: 'brew' | 'cask' | 'vscode' | 'apt' | 'github'
  modulo: 'base' | 'cloud' | 'k8s' | 'gui'
  plataforma: 'macos' | 'linux'
  fuente: string       // ruta relativa del fichero, p.ej. 'Brewfile.cloud'
  repo?: string        // 'owner/repo' cuando tipo === 'github'
  categoriaBrewfile?: string
}
```

- [ ] **Paso 1: Definir los tipos compartidos**

`web/src/data/types.ts`:

```ts
export type Modulo = 'base' | 'cloud' | 'k8s' | 'gui'
export type Plataforma = 'macos' | 'linux'
export type TipoEntrada = 'brew' | 'cask' | 'vscode' | 'apt' | 'github'

/** Lo que el repo declara. Generado, nunca escrito a mano. */
export interface Entrada {
  clave: string
  nombre: string
  tipo: TipoEntrada
  modulo: Modulo
  plataforma: Plataforma
  fuente: string
  repo?: string
  categoriaBrewfile?: string
}

/** Lo que una máquina no puede saber. Escrito a mano. */
export interface Curada {
  id: string
  nombre: string
  categoria: string
  descripcion: string
  url: string
  /** Claves de `Entrada` que esta ficha cubre, p.ej. ['brew:fd', 'apt:fd-find']. */
  declarado: string[]
}

export interface Preset {
  flag: string
  cloud: boolean
  k8s: boolean
  gui: boolean
}

export interface Generado {
  entradas: Entrada[]
  presets: Preset[]
  conteos: Record<string, number>
}

/** Lo que consume la UI: una ficha curada + de dónde sale realmente. */
export interface Herramienta extends Omit<Curada, 'declarado'> {
  modulos: Modulo[]
  plataformas: Plataforma[]
  entradas: Entrada[]
}
```

- [ ] **Paso 2: Escribir el test que falla**

`web/scripts/extract-brew.test.mjs`:

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerBrew } from './extract-brew.mjs'

function repoFalso(ficheros) {
  const dir = mkdtempSync(join(tmpdir(), 'brewtest-'))
  for (const [nombre, contenido] of Object.entries(ficheros)) {
    writeFileSync(join(dir, nombre), contenido)
  }
  return dir
}

test('extrae brew, cask y vscode con su categoría', () => {
  const dir = repoFalso({
    'Brewfile': [
      '# --- Core CLI ---',
      'brew "git"',
      'brew "tmux"',
      '',
      '# --- Modern CLI (Rust-powered) ---',
      'brew "bat"',
      'cask "wezterm"',
    ].join('\n'),
    'Brewfile.cloud': '# --- Cloud CLIs ---\nbrew "awscli"\n',
    'Brewfile.k8s': '# --- Kubernetes core ---\nbrew "kubectl"\n',
    'Brewfile.gui': '# --- VS Code Extensions ---\nvscode "golang.go"\n',
  })

  const entradas = extraerBrew(dir)
  const porClave = Object.fromEntries(entradas.map((e) => [e.clave, e]))

  assert.equal(entradas.length, 7)
  assert.deepEqual(porClave['brew:bat'], {
    clave: 'brew:bat',
    nombre: 'bat',
    tipo: 'brew',
    modulo: 'base',
    plataforma: 'macos',
    fuente: 'Brewfile',
    categoriaBrewfile: 'Modern CLI (Rust-powered)',
  })
  assert.equal(porClave['cask:wezterm'].tipo, 'cask')
  assert.equal(porClave['brew:awscli'].modulo, 'cloud')
  assert.equal(porClave['brew:kubectl'].modulo, 'k8s')
  assert.equal(porClave['vscode:golang.go'].modulo, 'gui')
})

test('ignora comentarios, taps y líneas en blanco', () => {
  const dir = repoFalso({
    'Brewfile': [
      '# comentario suelto',
      'tap "hashicorp/tap"',
      '',
      '   brew "jq"   ',
      '# brew "comentado"',
    ].join('\n'),
    'Brewfile.cloud': '',
    'Brewfile.k8s': '',
    'Brewfile.gui': '',
  })

  const entradas = extraerBrew(dir)
  assert.deepEqual(entradas.map((e) => e.clave), ['brew:jq'])
})

test('rechaza una fórmula declarada en dos Brewfiles', () => {
  const dir = repoFalso({
    'Brewfile': 'brew "jq"\n',
    'Brewfile.cloud': 'brew "jq"\n',
    'Brewfile.k8s': '',
    'Brewfile.gui': '',
  })

  assert.throws(() => extraerBrew(dir), /brew:jq.*Brewfile.*Brewfile\.cloud/s)
})
```

- [ ] **Paso 3: Ejecutar el test y ver que falla**

```bash
cd web && node --test scripts/extract-brew.test.mjs
```

Esperado: FAIL — `Cannot find module '.../extract-brew.mjs'`.

- [ ] **Paso 4: Implementar el parser**

`web/scripts/extract-brew.mjs`:

```js
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const FICHEROS = [
  ['Brewfile', 'base'],
  ['Brewfile.cloud', 'cloud'],
  ['Brewfile.k8s', 'k8s'],
  ['Brewfile.gui', 'gui'],
]

const CATEGORIA = /^#\s*---\s*(.+?)\s*---\s*$/
const DECLARACION = /^(brew|cask|vscode)\s+"([^"]+)"/

/**
 * Extrae las herramientas declaradas en los cuatro Brewfiles.
 * Son macOS-only por definición: en Linux nadie corre `brew bundle`.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Entrada[]}
 */
export function extraerBrew(rutaRepo) {
  const entradas = []
  const vistas = new Map()

  for (const [fichero, modulo] of FICHEROS) {
    const texto = readFileSync(join(rutaRepo, fichero), 'utf8')
    let categoria

    for (const cruda of texto.split('\n')) {
      const linea = cruda.trim()

      const cat = linea.match(CATEGORIA)
      if (cat) {
        categoria = cat[1]
        continue
      }
      // Un `#` inicial que no sea cabecera de categoría es prosa: fuera.
      // Va después del match de categoría, no antes.
      if (linea.startsWith('#') || linea === '') continue

      const decl = linea.match(DECLARACION)
      if (!decl) continue // `tap "..."` y cualquier otra directiva

      const [, tipo, nombre] = decl
      const clave = `${tipo}:${nombre}`

      const previa = vistas.get(clave)
      if (previa) {
        throw new Error(
          `${clave} está declarada en dos sitios: ${previa} y ${fichero}. ` +
            `Una fórmula en dos Brewfiles se instala dos veces y su módulo es ambiguo.`,
        )
      }
      vistas.set(clave, fichero)

      const entrada = {
        clave,
        nombre,
        tipo,
        modulo,
        plataforma: 'macos',
        fuente: fichero,
      }
      if (categoria) entrada.categoriaBrewfile = categoria
      entradas.push(entrada)
    }
  }

  return entradas
}
```

- [ ] **Paso 5: Ejecutar los tests y ver que pasan**

```bash
cd web && node --test scripts/extract-brew.test.mjs
```

Esperado: `# pass 3`, `# fail 0`.

- [ ] **Paso 6: Comprobar contra los ficheros reales**

```bash
cd web && node -e "
import('./scripts/extract-brew.mjs').then(({extraerBrew}) => {
  const e = extraerBrew('..')
  const porModulo = {}
  for (const x of e) porModulo[x.modulo] = (porModulo[x.modulo] ?? 0) + 1
  console.log(e.length, porModulo)
})"
```

Esperado: un total ≥ 125 y los cuatro módulos con conteo > 0. Si `base` sale 0, el parser de categorías se está comiendo las declaraciones.

- [ ] **Paso 7: Commit**

```bash
git add web/scripts/extract-brew.mjs web/scripts/extract-brew.test.mjs web/src/data/types.ts
git commit -m 'feat(web): extraer las herramientas de los Brewfiles

Primera de las cuatro fuentes del catalogo. Lanza si una formula aparece en
dos Brewfiles: se instalaria dos veces y su modulo seria ambiguo, asi que es
un fallo del repo que merece ruido y no una entrada duplicada en la web.'
```

---

### Task 3: Extractor de `lib/binaries.sh`

Es el parser delicado: tres patrones distintos y gating por bloque.

**Ficheros:**
- Crear: `web/scripts/extract-binaries.mjs`, `web/scripts/extract-binaries.test.mjs`

**Interfaces:**
- Consume: el tipo `Entrada` de la Task 2.
- Produce: `extraerBinarios(rutaRepo: string): Entrada[]`, todas con `plataforma: 'linux'` y `tipo: 'github'`.

**Contexto que el implementador necesita.** `lib/binaries.sh` declara herramientas de **tres formas** y hay que cazar las tres. Mirar solo la primera deja fuera `kubectl`, `helm`, `kubectx`, `kubens` y `tofu` — las cinco más visibles del catálogo — sin dar ningún error:

1. `install_if_missing "nombre" \` — la mayoría.
2. `if ! command -v nombre >/dev/null 2>&1; then` — instaladores a medida (kubectl, helm, kubectx, tofu).
3. `gh_latest_tar owner/repo "patrón" "$LOCAL_BIN" nombre` — llamadas directas dentro de un instalador a medida (kubectx, kubens). Ojo: **con `"$LOCAL_BIN"` entrecomillado**. Las llamadas dentro de una cadena de `install_if_missing` lo llevan sin comillas, y no deben matchear aquí porque ya las coge el patrón 1.

El módulo sale del bloque que envuelve la línea: `if [[ $INSTALL_K8S -eq 1 ]]` → `k8s`, `if [[ $INSTALL_CLOUD -eq 1 ]]` → `cloud`, fuera de ambos → `base`. Los bloques se cierran con un `fi` a **la misma columna** que su `if`; dentro hay `if`/`fi` anidados más indentados que hay que ignorar.

- [ ] **Paso 1: Escribir el test que falla**

`web/scripts/extract-binaries.test.mjs`:

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerBinarios } from './extract-binaries.mjs'

function repoFalso(contenido) {
  const dir = mkdtempSync(join(tmpdir(), 'bintest-'))
  mkdirSync(join(dir, 'lib'))
  writeFileSync(join(dir, 'lib/binaries.sh'), contenido)
  return dir
}

const GUION = `
phase_binaries() {
    if [[ $IS_MAC -eq 0 ]]; then
        install_if_missing "lazygit" \\
            "gh_latest_tar jesseduffield/lazygit 'linux.tar.gz' $LOCAL_BIN lazygit"

        install_if_missing "yamllint" "uv tool install yamllint"

        if [[ $INSTALL_K8S -eq 1 ]]; then
            install_if_missing "k9s" \\
                "gh_latest_tar derailed/k9s 'Linux.tar.gz' $LOCAL_BIN k9s"

            if ! command -v kubectl >/dev/null 2>&1; then
                log "Instalando kubectl..."
            else
                ok "kubectl ya instalado"
            fi

            if ! command -v kubectx >/dev/null 2>&1; then
                gh_latest_tar ahmetb/kubectx "kubectx_linux.tar.gz" "$LOCAL_BIN" kubectx
                gh_latest_tar ahmetb/kubectx "kubens_linux.tar.gz" "$LOCAL_BIN" kubens
            fi
        else
            warn "Skipping k8s"
        fi

        if [[ $INSTALL_CLOUD -eq 1 ]]; then
            install_if_missing "tflint" \\
                "gh_latest_zip terraform-linters/tflint 'linux.zip' $LOCAL_BIN"

            if ! command -v tofu >/dev/null 2>&1; then
                log "Instalando OpenTofu..."
            fi
        fi
    fi
}
`

test('caza los tres patrones de declaración', () => {
  const entradas = extraerBinarios(repoFalso(GUION))
  const nombres = entradas.map((e) => e.nombre).sort()

  assert.deepEqual(nombres, [
    'k9s', 'kubectl', 'kubectx', 'kubens', 'lazygit', 'tflint', 'tofu', 'yamllint',
  ])
})

test('asigna el módulo según el bloque que envuelve la línea', () => {
  const porNombre = Object.fromEntries(
    extraerBinarios(repoFalso(GUION)).map((e) => [e.nombre, e.modulo]),
  )

  assert.equal(porNombre.lazygit, 'base')
  assert.equal(porNombre.yamllint, 'base')
  assert.equal(porNombre.k9s, 'k8s')
  assert.equal(porNombre.kubectl, 'k8s')
  assert.equal(porNombre.kubens, 'k8s')
  assert.equal(porNombre.tflint, 'cloud')
  assert.equal(porNombre.tofu, 'cloud')
})

test('los if anidados no cierran el bloque de gating', () => {
  // tofu vive tras un if/fi anidado dentro del bloque cloud. Si el parser
  // cerrara el gating con el primer `fi` que ve, tofu saldría como base.
  const porNombre = Object.fromEntries(
    extraerBinarios(repoFalso(GUION)).map((e) => [e.nombre, e.modulo]),
  )
  assert.equal(porNombre.tofu, 'cloud')
})

test('marca todo como linux, github y con clave prefijada', () => {
  const lazygit = extraerBinarios(repoFalso(GUION)).find((e) => e.nombre === 'lazygit')

  assert.equal(lazygit.plataforma, 'linux')
  assert.equal(lazygit.tipo, 'github')
  assert.equal(lazygit.clave, 'github:lazygit')
  assert.equal(lazygit.fuente, 'lib/binaries.sh')
})

test('no duplica una herramienta declarada por dos patrones', () => {
  const dir = repoFalso(`
        install_if_missing "kubectx" "algo"
        if ! command -v kubectx >/dev/null 2>&1; then
            gh_latest_tar ahmetb/kubectx "x.tar.gz" "$LOCAL_BIN" kubectx
        fi
`)
  assert.deepEqual(extraerBinarios(dir).map((e) => e.nombre), ['kubectx'])
})
```

- [ ] **Paso 2: Ejecutar el test y ver que falla**

```bash
cd web && node --test scripts/extract-binaries.test.mjs
```

Esperado: FAIL — `Cannot find module '.../extract-binaries.mjs'`.

- [ ] **Paso 3: Implementar el parser**

`web/scripts/extract-binaries.mjs`:

```js
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const FUENTE = 'lib/binaries.sh'

// Los tres patrones con los que binaries.sh declara una herramienta.
// Mirar solo el primero deja fuera kubectl, helm, kubectx, kubens y tofu.
const INSTALL_IF_MISSING = /^\s*install_if_missing\s+"([^"]+)"/
const COMMAND_V = /^\s*if\s+!\s+command\s+-v\s+([A-Za-z0-9_.-]+)\s/
// `"$LOCAL_BIN"` entrecomillado: así solo casan las llamadas directas, no las
// que van dentro de la cadena de un install_if_missing (que lo llevan sin
// comillas y ya las coge INSTALL_IF_MISSING).
const GH_DIRECTO = /gh_latest_tar\s+(\S+)\s+"[^"]*"\s+"\$LOCAL_BIN"\s+([A-Za-z0-9_.-]+)/

const APERTURA_GATING = /^(\s*)if\s+\[\[\s+\$INSTALL_(K8S|CLOUD)\s+-eq\s+1\s+\]\]/
const CIERRE = /^(\s*)fi\b/

/** Repo de GitHub asociado a la línea, si la línea lo nombra. */
function repoDe(linea) {
  const m = linea.match(/gh_latest_(?:tar|bin|zip)\s+([A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+)/)
  return m ? m[1] : undefined
}

/**
 * Extrae las herramientas que el instalador baja en Linux.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Entrada[]}
 */
export function extraerBinarios(rutaRepo) {
  const lineas = readFileSync(join(rutaRepo, FUENTE), 'utf8').split('\n')

  /** @type {{sangria: string, modulo: 'k8s'|'cloud'}[]} */
  const pila = []
  /** @type {Map<string, import('../src/data/types.ts').Entrada>} */
  const porNombre = new Map()

  const moduloActual = () => (pila.length ? pila[pila.length - 1].modulo : 'base')

  const registrar = (nombre, repo) => {
    const existente = porNombre.get(nombre)
    if (existente) {
      // Ya declarada por otro patrón: completa el repo si faltaba y no dupliques.
      if (!existente.repo && repo) existente.repo = repo
      return
    }
    const entrada = {
      clave: `github:${nombre}`,
      nombre,
      tipo: 'github',
      modulo: moduloActual(),
      plataforma: 'linux',
      fuente: FUENTE,
    }
    if (repo) entrada.repo = repo
    porNombre.set(nombre, entrada)
  }

  for (const linea of lineas) {
    // El cierre se evalúa antes que la apertura: un `fi` a la columna del `if`
    // de gating lo cierra; cualquier `fi` más indentado es de un if anidado.
    const cierre = linea.match(CIERRE)
    if (cierre && pila.length && cierre[1].length <= pila[pila.length - 1].sangria.length) {
      pila.pop()
      continue
    }

    const apertura = linea.match(APERTURA_GATING)
    if (apertura) {
      pila.push({ sangria: apertura[1], modulo: apertura[2] === 'K8S' ? 'k8s' : 'cloud' })
      continue
    }

    const iim = linea.match(INSTALL_IF_MISSING)
    if (iim) { registrar(iim[1], repoDe(linea)); continue }

    const cmd = linea.match(COMMAND_V)
    if (cmd) { registrar(cmd[1], undefined); continue }

    const gh = linea.match(GH_DIRECTO)
    if (gh) { registrar(gh[2], gh[1]); continue }
  }

  return [...porNombre.values()]
}
```

> Sobre `install_if_missing "lazygit" \`: el repo del proyecto va en la **línea siguiente**, así que `repoDe` devuelve `undefined` para esas entradas. Es correcto y deliberado: la URL del proyecto la aporta el fichero curado, y `repo` aquí es solo un extra cuando cae gratis. No añadas lectura multilínea para rellenarlo.

- [ ] **Paso 4: Ejecutar los tests y ver que pasan**

```bash
cd web && node --test scripts/extract-binaries.test.mjs
```

Esperado: `# pass 5`, `# fail 0`.

- [ ] **Paso 5: Comprobar contra el fichero real**

```bash
cd web && node -e "
import('./scripts/extract-binaries.mjs').then(({extraerBinarios}) => {
  const e = extraerBinarios('..')
  console.log('total:', e.length)
  console.log('k8s:', e.filter(x=>x.modulo==='k8s').map(x=>x.nombre).join(' '))
  console.log('cloud:', e.filter(x=>x.modulo==='cloud').map(x=>x.nombre).join(' '))
})"
```

Esperado: total ≥ 30; en `k8s` aparecen al menos `k9s stern kubeshark dive kubectl kubectx kubens`; en `cloud`, al menos `tflint tofu`. **Si `kubectl` o `tofu` no aparecen, el parser está mal** — son la razón de que haya tres patrones.

- [ ] **Paso 6: Commit**

```bash
git add web/scripts/extract-binaries.mjs web/scripts/extract-binaries.test.mjs
git commit -m 'feat(web): extraer las herramientas de lib/binaries.sh

Tres patrones y no uno: kubectl, helm, kubectx, kubens y tofu no pasan por
install_if_missing sino por bloques `if ! command -v` a medida. Un parser que
solo mirase install_if_missing se dejaria fuera las cinco mas visibles del
catalogo sin dar ningun error.

El cierre del gating se compara por columna porque dentro de los bloques
INSTALL_K8S e INSTALL_CLOUD hay if/fi anidados; con el primer `fi` que aparece,
tofu saldria clasificado como base.'
```

---

### Task 4: Extractores de apt y de los presets

**Ficheros:**
- Crear: `web/scripts/extract-apt.mjs`, `web/scripts/extract-apt.test.mjs`
- Crear: `web/scripts/extract-presets.mjs`, `web/scripts/extract-presets.test.mjs`

**Interfaces:**
- Consume: los tipos de la Task 2.
- Produce: `extraerApt(rutaRepo: string): Entrada[]` y `extraerPresets(rutaRepo: string): Preset[]`.

- [ ] **Paso 1: Escribir el test de apt**

`web/scripts/extract-apt.test.mjs`:

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerApt } from './extract-apt.mjs'

function repoFalso(contenido) {
  const dir = mkdtempSync(join(tmpdir(), 'apttest-'))
  mkdirSync(join(dir, 'lib'))
  writeFileSync(join(dir, 'lib/packages.sh'), contenido)
  return dir
}

const GUION = `
phase_packages() {
            sudo apt update
            sudo apt install -y zsh tmux git curl jq \\
                zsh-autosuggestions bsdextrautils 2>/dev/null || true

            sudo DEBIAN_FRONTEND=noninteractive apt install -y \\
                mtr-tiny nmap socat 2>/dev/null || true

            if [[ $INSTALL_CLOUD -eq 1 ]]; then
                sudo apt install -y postgresql-client 2>/dev/null || true
            fi
}
`

test('extrae los paquetes de todas las invocaciones de apt install', () => {
  const nombres = extraerApt(repoFalso(GUION)).map((e) => e.nombre).sort()

  assert.deepEqual(nombres, [
    'bsdextrautils', 'curl', 'git', 'jq', 'mtr-tiny', 'nmap',
    'postgresql-client', 'socat', 'tmux', 'zsh', 'zsh-autosuggestions',
  ])
})

test('respeta el gating de cloud y descarta el ruido de la línea', () => {
  const porNombre = Object.fromEntries(
    extraerApt(repoFalso(GUION)).map((e) => [e.nombre, e]),
  )

  assert.equal(porNombre['zsh'].modulo, 'base')
  assert.equal(porNombre['postgresql-client'].modulo, 'cloud')
  assert.equal(porNombre['zsh'].plataforma, 'linux')
  assert.equal(porNombre['zsh'].tipo, 'apt')
  assert.equal(porNombre['zsh'].clave, 'apt:zsh')
  // `2>/dev/null`, `||`, `true` y `-y` no son paquetes.
  assert.equal(porNombre['true'], undefined)
  assert.equal(porNombre['-y'], undefined)
})

test('ignora apt update, que no instala nada', () => {
  const nombres = extraerApt(repoFalso('sudo apt update\n')).map((e) => e.nombre)
  assert.deepEqual(nombres, [])
})
```

- [ ] **Paso 2: Ejecutar y ver que falla**

```bash
cd web && node --test scripts/extract-apt.test.mjs
```

Esperado: FAIL — módulo no encontrado.

- [ ] **Paso 3: Implementar `extract-apt.mjs`**

```js
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const FUENTE = 'lib/packages.sh'

const APT_INSTALL = /\bapt(?:-get)?\s+install\s+(.*)$/
const APERTURA_GATING = /^(\s*)if\s+\[\[\s+\$INSTALL_(K8S|CLOUD)\s+-eq\s+1\s+\]\]/
const CIERRE = /^(\s*)fi\b/
// Un paquete de Debian: letras, dígitos y `+ - . :`. Todo lo demás de la línea
// (flags, redirecciones, `||`, `true`) se descarta.
const PAQUETE = /^[a-z0-9][a-z0-9+.:-]*$/

/**
 * Extrae los paquetes que el instalador pone con apt en Debian/Ubuntu.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Entrada[]}
 */
export function extraerApt(rutaRepo) {
  const lineas = readFileSync(join(rutaRepo, FUENTE), 'utf8').split('\n')

  const pila = []
  const porNombre = new Map()
  const moduloActual = () => (pila.length ? pila[pila.length - 1].modulo : 'base')

  for (let i = 0; i < lineas.length; i++) {
    const linea = lineas[i]

    const cierre = linea.match(CIERRE)
    if (cierre && pila.length && cierre[1].length <= pila[pila.length - 1].sangria.length) {
      pila.pop()
      continue
    }

    const apertura = linea.match(APERTURA_GATING)
    if (apertura) {
      pila.push({ sangria: apertura[1], modulo: apertura[2] === 'K8S' ? 'k8s' : 'cloud' })
      continue
    }

    const apt = linea.match(APT_INSTALL)
    if (!apt) continue

    // Une las continuaciones con `\` para no perder la segunda mitad de la lista.
    let resto = apt[1]
    let j = i
    while (resto.trimEnd().endsWith('\\')) {
      resto = resto.trimEnd().slice(0, -1) + ' ' + (lineas[++j] ?? '')
    }
    i = j

    // Corta en el primer operador de shell: lo de después no son paquetes.
    resto = resto.split(/\s(?:2>|1>|>|\|\||&&|;)/)[0]

    for (const trozo of resto.split(/\s+/)) {
      if (!trozo || trozo.startsWith('-') || !PAQUETE.test(trozo)) continue
      const modulo = moduloActual()
      if (!porNombre.has(trozo)) {
        porNombre.set(trozo, {
          clave: `apt:${trozo}`,
          nombre: trozo,
          tipo: 'apt',
          modulo,
          plataforma: 'linux',
          fuente: FUENTE,
        })
      }
    }
  }

  return [...porNombre.values()]
}
```

- [ ] **Paso 4: Ejecutar los tests de apt**

```bash
cd web && node --test scripts/extract-apt.test.mjs
```

Esperado: `# pass 3`, `# fail 0`.

- [ ] **Paso 5: Escribir el test de presets**

`web/scripts/extract-presets.test.mjs`:

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerPresets } from './extract-presets.mjs'

function repoFalso(contenido) {
  const dir = mkdtempSync(join(tmpdir(), 'presettest-'))
  writeFileSync(join(dir, 'install.sh'), contenido)
  return dir
}

const GUION = `
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=1 ;;
        --minimal)   INSTALL_CLOUD=0; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --vps)       INSTALL_CLOUD=1; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --k8s-node)  INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --agent)     INSTALL_AGENT=1; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --no-cloud)  INSTALL_CLOUD=0; PROFILE_FLAG=1 ;;
    esac
done
`

test('extrae solo los presets, no las flags sueltas', () => {
  const flags = extraerPresets(repoFalso(GUION)).map((p) => p.flag)
  assert.deepEqual(flags, ['--minimal', '--vps', '--k8s-node', '--agent'])
})

test('lee los módulos que enciende cada preset', () => {
  const porFlag = Object.fromEntries(extraerPresets(repoFalso(GUION)).map((p) => [p.flag, p]))

  assert.deepEqual(porFlag['--vps'], { flag: '--vps', cloud: true, k8s: false, gui: false })
  assert.deepEqual(porFlag['--k8s-node'], { flag: '--k8s-node', cloud: true, k8s: true, gui: false })
})

test('--agent hereda cloud y k8s encendidos porque no los toca', () => {
  // No es un descuido del parser: --agent es ortogonal a la carga de la
  // máquina, así que deja cloud y k8s en su valor por defecto (1).
  const agent = extraerPresets(repoFalso(GUION)).find((p) => p.flag === '--agent')
  assert.deepEqual(agent, { flag: '--agent', cloud: true, k8s: true, gui: false })
})
```

- [ ] **Paso 6: Implementar `extract-presets.mjs`**

```js
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const FUENTE = 'install.sh'

// Solo las ramas del case que fijan PROFILE_FLAG=1 son presets; --dry-run y
// --update no lo hacen. Las --no-* se excluyen aparte: son modificadores.
const RAMA = /^\s*(--[a-z0-9-]+)\)\s*(.*?)\s*;;/

/**
 * Lee de install.sh qué módulos enciende cada preset.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Preset[]}
 */
export function extraerPresets(rutaRepo) {
  const lineas = readFileSync(join(rutaRepo, FUENTE), 'utf8').split('\n')
  const presets = []

  for (const linea of lineas) {
    const m = linea.match(RAMA)
    if (!m) continue

    const [, flag, cuerpo] = m
    if (!cuerpo.includes('PROFILE_FLAG=1')) continue
    if (flag.startsWith('--no-')) continue

    // Por defecto los tres módulos están encendidos; un preset solo apaga lo
    // que nombra. --agent no nombra cloud ni k8s, y los hereda en ON.
    const leer = (nombre) => {
      const v = cuerpo.match(new RegExp(`INSTALL_${nombre}=([01])`))
      return v ? v[1] === '1' : true
    }

    presets.push({ flag, cloud: leer('CLOUD'), k8s: leer('K8S'), gui: leer('GUI') })
  }

  return presets
}
```

- [ ] **Paso 7: Ejecutar todos los tests**

```bash
cd web && node --test scripts/
```

Esperado: `# fail 0`. Comprueba también contra el fichero real:

```bash
cd web && node -e "
import('./scripts/extract-presets.mjs').then(({extraerPresets}) =>
  console.log(JSON.stringify(extraerPresets('..'), null, 1)))"
```

Esperado: cinco presets — `--minimal`, `--vps`, `--container`, `--k8s-node`, `--agent` — y `--agent` con `cloud: true, k8s: true, gui: false`.

- [ ] **Paso 8: Commit**

```bash
git add web/scripts/extract-apt.mjs web/scripts/extract-apt.test.mjs web/scripts/extract-presets.mjs web/scripts/extract-presets.test.mjs
git commit -m 'feat(web): extraer los paquetes apt y los presets de install.sh

Los presets se leen de las ramas del case que fijan PROFILE_FLAG=1, asi que la
tabla comparativa de la web no puede contradecir al instalador. --agent sale
con cloud y k8s en ON porque no los toca, que es justo lo que documenta su
spec: son ortogonales a quien usa la caja.'
```

---

### Task 5: Orquestador y `tools.generated.json`

**Ficheros:**
- Crear: `web/scripts/extract-tools.mjs`
- Crear (generado): `web/src/data/tools.generated.json`

**Interfaces:**
- Consume: `extraerBrew`, `extraerBinarios`, `extraerApt`, `extraerPresets`.
- Produce: `extraerTodo(rutaRepo: string): Generado` (exportada, la usa el checker de la Task 6) y, al ejecutarse como script, escribe `web/src/data/tools.generated.json`.

- [ ] **Paso 1: Implementar el orquestador**

`web/scripts/extract-tools.mjs`:

```js
import { writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { extraerBrew } from './extract-brew.mjs'
import { extraerBinarios } from './extract-binaries.mjs'
import { extraerApt } from './extract-apt.mjs'
import { extraerPresets } from './extract-presets.mjs'

export const RAIZ_REPO = join(import.meta.dirname, '..', '..')
export const DESTINO = join(import.meta.dirname, '..', 'src', 'data', 'tools.generated.json')

/**
 * Reúne las cuatro fuentes en el modelo que consume la web.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Generado}
 */
export function extraerTodo(rutaRepo) {
  const entradas = [
    ...extraerBrew(rutaRepo),
    ...extraerBinarios(rutaRepo),
    ...extraerApt(rutaRepo),
  ].sort((a, b) => a.clave.localeCompare(b.clave))

  const conteos = {}
  for (const e of entradas) conteos[e.fuente] = (conteos[e.fuente] ?? 0) + 1

  return { entradas, presets: extraerPresets(rutaRepo), conteos }
}

/** Serialización estable: mismo repo, mismo byte. */
export function serializar(generado) {
  return JSON.stringify(generado, null, 2) + '\n'
}

if (process.argv[1] === import.meta.filename) {
  const generado = extraerTodo(RAIZ_REPO)
  writeFileSync(DESTINO, serializar(generado))
  console.log(
    `tools.generated.json: ${generado.entradas.length} entradas, ` +
      `${generado.presets.length} presets`,
  )
  for (const [fuente, n] of Object.entries(generado.conteos)) {
    console.log(`  ${fuente}: ${n}`)
  }
}
```

- [ ] **Paso 2: Generar el fichero y revisarlo a ojo**

```bash
cd web && npm run extract
```

Esperado: imprime el total y el desglose por fuente. Revisa que no haya basura:

```bash
cd web && node -e "
const g = require('fs').readFileSync('src/data/tools.generated.json','utf8')
const d = JSON.parse(g)
console.log('claves duplicadas:', d.entradas.length - new Set(d.entradas.map(e=>e.clave)).size)
console.log('sin nombre:', d.entradas.filter(e=>!e.nombre).length)
console.log(d.entradas.slice(0,3))"
```

Esperado: `claves duplicadas: 0`, `sin nombre: 0`.

- [ ] **Paso 3: Test de regresión contra los ficheros reales**

Los tests de las Tasks 2–4 corren sobre fixtures, así que pasarían aunque el
parser dejase de ver el fichero real entero. Este test cierra ese hueco y fija
por escrito el hallazgo que motivó los tres patrones.

`web/scripts/extract-real.test.mjs`:

```js
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { extraerTodo, RAIZ_REPO } from './extract-tools.mjs'

const datos = extraerTodo(RAIZ_REPO)
const nombres = new Set(datos.entradas.map((e) => e.nombre))
const claves = new Set(datos.entradas.map((e) => e.clave))

test('ninguna clave duplicada', () => {
  assert.equal(datos.entradas.length, claves.size)
})

test('las cinco que no pasan por install_if_missing siguen apareciendo', () => {
  // kubectl, helm, kubectx, kubens y tofu se instalan con bloques
  // `if ! command -v x` a medida. Un parser que solo mirase
  // install_if_missing las omitiría sin dar ningún error.
  for (const n of ['kubectl', 'helm', 'kubectx', 'kubens', 'tofu']) {
    assert.ok(nombres.has(n), `${n} desapareció del extractor de lib/binaries.sh`)
  }
})

test('el gating de lib/binaries.sh clasifica bien', () => {
  const porNombre = Object.fromEntries(
    datos.entradas.filter((e) => e.tipo === 'github').map((e) => [e.nombre, e.modulo]),
  )
  assert.equal(porNombre.k9s, 'k8s')
  assert.equal(porNombre.kubectl, 'k8s')
  assert.equal(porNombre.tofu, 'cloud')
  assert.equal(porNombre.tflint, 'cloud')
  assert.equal(porNombre.lazygit, 'base')
})

test('las cuatro fuentes aportan entradas', () => {
  for (const fuente of ['Brewfile', 'Brewfile.cloud', 'Brewfile.k8s', 'Brewfile.gui',
                        'lib/binaries.sh', 'lib/packages.sh']) {
    assert.ok((datos.conteos[fuente] ?? 0) > 0, `${fuente} no aportó ninguna entrada`)
  }
})

test('los cinco presets se leen de install.sh', () => {
  const flags = datos.presets.map((p) => p.flag).sort()
  assert.deepEqual(flags, ['--agent', '--container', '--k8s-node', '--minimal', '--vps'])
})

test('--agent hereda cloud y k8s encendidos, y apaga gui', () => {
  const agent = datos.presets.find((p) => p.flag === '--agent')
  assert.deepEqual(agent, { flag: '--agent', cloud: true, k8s: true, gui: false })
})
```

Ejecutar:

```bash
cd web && node --test scripts/extract-real.test.mjs
```

Esperado: `# pass 6`, `# fail 0`. Si falla el segundo, el parser de la Task 3 se
rompió: no lo "arregles" bajando la aserción.

- [ ] **Paso 4: Commit**

```bash
git add web/scripts/extract-tools.mjs web/scripts/extract-real.test.mjs web/src/data/tools.generated.json
git commit -m 'feat(web): generar tools.generated.json desde las cuatro fuentes

El JSON se versiona a proposito. Asi el diff de anadir un brew se ve en la PR
y el deploy no depende de que el parser corra bien en un runner: si el fichero
esta rancio, la guardia lo detecta comparando en vez de regenerarlo en silencio.'
```

---

### Task 6: Fichero curado y guardia bidireccional

Es la tarea que hace honesto al catálogo.

**Ficheros:**
- Crear: `web/src/data/tools.curated.json`, `web/scripts/check-tools.mjs`, `web/src/data/herramientas.ts`

**Interfaces:**
- Consume: `extraerTodo` y `serializar` de la Task 5; los tipos de la Task 2.
- Produce: `herramientas: Herramienta[]` y `presets: Preset[]` exportados de `@/data/herramientas`, que consumen las tareas de UI.

- [ ] **Paso 1: Escribir el checker**

`web/scripts/check-tools.mjs`. Falla en cuatro situaciones distintas y cada una con su mensaje: JSON rancio, herramienta sin ficha, ficha huérfana, y conteo por debajo del mínimo.

```js
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { extraerTodo, serializar, RAIZ_REPO, DESTINO } from './extract-tools.mjs'

const CURADO = join(import.meta.dirname, '..', 'src', 'data', 'tools.curated.json')

// Suelo por fuente. Existen porque el parser es regex sobre bash y "dejar de
// ver" una herramienta no produce ningún error: sin esto, romper la forma de las
// arrays de binaries.sh publicaría un catálogo mutilado con el CI en verde.
//
// Calibrados al ~75% del recuento real, no a un pelo por debajo. Lo que tienen
// que cazar es que el parser deje de casar —eso tumba el conteo a la mitad o a
// cero—, no que retires una herramienta a propósito. Un suelo pegado al valor
// real convierte cada retirada legítima en un build rojo, y una guardia que da
// falsos positivos es una guardia que se acaba bajando sin mirar.
//
// Se suben al añadir herramientas y SOLO se bajan a mano, en el mismo commit que
// retira la herramienta y explicando por qué. Bajarlos para poner verde un build
// rojo es desactivar la guardia.
//
// Recuentos reales al escribir esto: Brewfile 73, .cloud 9, .k8s 15, .gui 32,
// binaries.sh 31, packages.sh 27.
const MINIMOS = {
  'Brewfile': 55,
  'Brewfile.cloud': 7,
  'Brewfile.k8s': 11,
  'Brewfile.gui': 24,
  'lib/binaries.sh': 23,
  'lib/packages.sh': 20,
}

const errores = []

const generado = extraerTodo(RAIZ_REPO)
const enDisco = readFileSync(DESTINO, 'utf8')

if (serializar(generado) !== enDisco) {
  errores.push(
    'tools.generated.json está desincronizado con el repo.\n' +
      '  Corre `npm run extract` y commitea el resultado.',
  )
}

const curadas = JSON.parse(readFileSync(CURADO, 'utf8'))

const declaradas = new Map()
for (const ficha of curadas) {
  for (const clave of ficha.declarado) {
    const previa = declaradas.get(clave)
    if (previa) {
      errores.push(`${clave} lo declaran dos fichas curadas: "${previa}" y "${ficha.id}".`)
    }
    declaradas.set(clave, ficha.id)
  }
}

const existentes = new Set(generado.entradas.map((e) => e.clave))

const huerfanas = [...existentes].filter((c) => !declaradas.has(c))
if (huerfanas.length) {
  errores.push(
    `${huerfanas.length} herramienta(s) del repo sin ficha en tools.curated.json:\n` +
      huerfanas.map((c) => `    ${c}`).join('\n') +
      '\n  Añade una ficha con nombre, categoria, descripcion y url.',
  )
}

const fantasmas = [...declaradas.keys()].filter((c) => !existentes.has(c))
if (fantasmas.length) {
  errores.push(
    `${fantasmas.length} ficha(s) curada(s) declaran algo que el repo ya no instala:\n` +
      fantasmas.map((c) => `    ${c} (ficha "${declaradas.get(c)}")`).join('\n') +
      '\n  Quita la ficha, o la clave sobrante de su `declarado`.',
  )
}

for (const [fuente, minimo] of Object.entries(MINIMOS)) {
  const real = generado.conteos[fuente] ?? 0
  if (real < minimo) {
    errores.push(
      `${fuente}: ${real} entradas, por debajo del mínimo de ${minimo}.\n` +
        '  O el parser dejó de casar, o se retiraron herramientas. Si fue lo\n' +
        '  segundo, baja el mínimo en check-tools.mjs en ese mismo commit.',
    )
  }
}

if (errores.length) {
  console.error('\n✖ check-tools:\n')
  for (const e of errores) console.error('  ' + e + '\n')
  process.exit(1)
}

console.log(
  `✔ check-tools: ${existentes.size} entradas cubiertas por ${curadas.length} fichas.`,
)
```

- [ ] **Paso 2: Ejecutar el checker con el curado vacío y leer la lista**

```bash
cd web && echo '[]' > src/data/tools.curated.json && node scripts/check-tools.mjs
```

Esperado: sale 1 y lista **todas** las claves sin ficha. Esa salida es la lista de trabajo del paso siguiente. Guárdala:

```bash
cd web && node scripts/check-tools.mjs 2>&1 | grep -oE '(brew|cask|vscode|apt|github):[^ ]+' | sort > /tmp/claves.txt && wc -l /tmp/claves.txt
```

- [ ] **Paso 3: Escribir `tools.curated.json`**

Una ficha por herramienta, cubriendo **todas** las claves de `/tmp/claves.txt`. Agrupa bajo una misma ficha las claves que son la misma herramienta en distintas plataformas — ese es el motivo de que `declarado` sea una lista.

Categorías a usar, exactamente estas cadenas: `Core`, `CLI moderna`, `Red y diagnóstico`, `Editor`, `Cloud e IaC`, `Kubernetes`, `Seguridad`, `Lenguajes`, `Terminal`, `Git`, `Misc`.

Formato, con los tres casos que aparecen:

```json
[
  {
    "id": "fd",
    "nombre": "fd",
    "categoria": "CLI moderna",
    "descripcion": "Buscador de ficheros por nombre, con sintaxis sensata y respeto por .gitignore.",
    "url": "https://github.com/sharkdp/fd",
    "declarado": ["brew:fd", "apt:fd-find"]
  },
  {
    "id": "k9s",
    "nombre": "k9s",
    "categoria": "Kubernetes",
    "descripcion": "TUI para navegar un clúster: pods, logs y shells sin escribir kubectl.",
    "url": "https://k9scli.io",
    "declarado": ["brew:k9s", "github:k9s"]
  },
  {
    "id": "wezterm",
    "nombre": "WezTerm",
    "categoria": "Terminal",
    "descripcion": "Emulador de terminal con GPU y configuración en Lua. Solo macOS.",
    "url": "https://wezfurlong.org/wezterm/",
    "declarado": ["cask:wezterm"]
  }
]
```

Reglas para las descripciones: **una frase, en español, que diga para qué sirve** —no qué es—, sin punto y coma encadenados y sin repetir el nombre al principio. Nada de "Herramienta que…".

- [ ] **Paso 4: Iterar hasta que el checker pase**

```bash
cd web && node scripts/check-tools.mjs
```

Repite hasta ver `✔ check-tools: N entradas cubiertas por M fichas.` con `# fail 0`.

- [ ] **Paso 5: Comprobar que la guardia muerde en las dos direcciones**

No basta con que pase: hay que ver que falla cuando debe.

```bash
cd web
# a) Ficha huérfana: añade un brew inventado al Brewfile del repo
echo 'brew "paquete-inventado"' >> ../Brewfile
npm run extract && node scripts/check-tools.mjs
```

Esperado: sale 1, con `brew:paquete-inventado` en la lista de "sin ficha".

```bash
# b) Ficha fantasma: quita el brew y NO regeneres
cd web && git checkout ../Brewfile && node scripts/check-tools.mjs
```

Esperado: sale 1, con el mensaje de `tools.generated.json` desincronizado.

```bash
# c) Deja todo limpio
cd web && npm run extract && node scripts/check-tools.mjs
```

Esperado: `✔ check-tools`. Comprueba que `git status --short` no lista `Brewfile`.

- [ ] **Paso 6: Escribir la API que consume la UI**

`web/src/data/herramientas.ts`:

```ts
import type { Curada, Entrada, Generado, Herramienta, Modulo, Plataforma, Preset } from './types'
import generado from './tools.generated.json'
import curadas from './tools.curated.json'

const datos = generado as Generado
const fichas = curadas as Curada[]

const porClave = new Map<string, Entrada>(datos.entradas.map((e) => [e.clave, e]))

/** Una ficha curada + las entradas reales que la respaldan. */
export const herramientas: Herramienta[] = fichas
  .map(({ declarado, ...ficha }) => {
    const entradas = declarado.map((c) => porClave.get(c)).filter((e): e is Entrada => Boolean(e))
    return {
      ...ficha,
      entradas,
      modulos: [...new Set(entradas.map((e) => e.modulo))] as Modulo[],
      plataformas: [...new Set(entradas.map((e) => e.plataforma))] as Plataforma[],
    }
  })
  .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))

export const presets: Preset[] = datos.presets

export const categorias: string[] = [...new Set(herramientas.map((h) => h.categoria))].sort((a, b) =>
  a.localeCompare(b, 'es'),
)

/** Cuántas herramientas trae un preset. El recuento sale del catálogo, no de una constante. */
export function cuentaDePreset(preset: Preset): number {
  return herramientas.filter((h) =>
    h.modulos.some(
      (m) =>
        m === 'base' ||
        (m === 'cloud' && preset.cloud) ||
        (m === 'k8s' && preset.k8s) ||
        (m === 'gui' && preset.gui),
    ),
  ).length
}
```

- [ ] **Paso 7: Comprobar que el build completo pasa**

```bash
cd web && npm run build
```

Esperado: `✔ check-tools: …` seguido del build de Next, sin errores de tipos.

- [ ] **Paso 8: Commit**

```bash
git add web/src/data/tools.curated.json web/src/data/herramientas.ts web/scripts/check-tools.mjs
git commit -m 'feat(web): guardia bidireccional del catalogo

Falla en las dos direcciones: una herramienta del repo sin ficha, y una ficha
que declara algo que el repo ya no instala. La segunda es la que de verdad
importa: es la deriva silenciosa que deja la web mintiendo.

Los minimos por fuente existen porque el parser es regex sobre bash y "dejar
de ver" una herramienta no produce ningun error. Sin ellos, reescribir la
forma de las arrays de binaries.sh publicaria un catalogo mutilado en verde.'
```

---

### Task 7: Componentes base y hero

**Ficheros:**
- Crear: `web/src/components/TerminalWindow.tsx`, `web/src/components/CopyButton.tsx`, `web/src/components/SectionHeading.tsx`, `web/src/components/Hero.tsx`
- Modificar: `web/src/app/page.tsx`

**Interfaces:**
- Consume: las clases de tema de la Task 1.
- Produce:
  - `<TerminalWindow titulo?: string, children: ReactNode>` — chrome reutilizable; lo usan las Tasks 8 y 10.
  - `<CopyButton texto: string>` — botón de copiar al portapapeles.
  - `<SectionHeading id: string, eyebrow: string, titulo: string, children?: ReactNode>` — cabecera de sección con ancla.

- [ ] **Paso 1: `TerminalWindow`**

```tsx
export function TerminalWindow({
  titulo,
  children,
}: {
  titulo?: string
  children: React.ReactNode
}) {
  return (
    <div className="overflow-hidden rounded-lg border border-surface0 bg-crust shadow-2xl shadow-black/40">
      <div className="flex items-center gap-2 border-b border-surface0 bg-surface0/60 px-4 py-2.5">
        <span className="size-3 rounded-full bg-red" />
        <span className="size-3 rounded-full bg-yellow" />
        <span className="size-3 rounded-full bg-green" />
        {titulo && (
          <span className="ml-2 font-mono text-xs text-overlay0">{titulo}</span>
        )}
      </div>
      <div className="p-5 font-mono text-sm leading-relaxed">{children}</div>
    </div>
  )
}
```

- [ ] **Paso 2: `CopyButton`**

```tsx
'use client'

import { useState } from 'react'

export function CopyButton({ texto }: { texto: string }) {
  const [copiado, setCopiado] = useState(false)

  async function copiar() {
    try {
      await navigator.clipboard.writeText(texto)
      setCopiado(true)
      setTimeout(() => setCopiado(false), 2000)
    } catch {
      // Sin permiso de portapapeles no hay nada que hacer: el comando está
      // visible y se puede seleccionar a mano.
    }
  }

  return (
    <button
      onClick={copiar}
      aria-label={copiado ? 'Comando copiado' : 'Copiar comando'}
      className="rounded-md border border-surface1 px-3 py-1.5 font-mono text-xs text-subtext0 transition hover:border-lavender hover:text-lavender"
    >
      {copiado ? '✓ copiado' : 'copiar'}
    </button>
  )
}
```

- [ ] **Paso 3: `SectionHeading`**

```tsx
export function SectionHeading({
  id,
  eyebrow,
  titulo,
  children,
}: {
  id: string
  eyebrow: string
  titulo: string
  children?: React.ReactNode
}) {
  return (
    <div className="mb-10 scroll-mt-24" id={id}>
      <p className="font-mono text-xs uppercase tracking-[0.2em] text-overlay0">{eyebrow}</p>
      <h2 className="mt-3 text-3xl font-bold tracking-tight text-text sm:text-4xl">{titulo}</h2>
      {children && <p className="mt-4 max-w-2xl text-subtext0">{children}</p>}
    </div>
  )
}
```

- [ ] **Paso 4: `Hero` con la animación de tecleo**

La animación respeta `prefers-reduced-motion`: si está activo, el comando aparece entero y sin cursor.

```tsx
'use client'

import { useEffect, useState } from 'react'
import { herramientas } from '@/data/herramientas'
import { CopyButton } from './CopyButton'
import { TerminalWindow } from './TerminalWindow'

const COMANDO = 'git clone https://github.com/kr0nicas/dotfiles ~/dotfiles && ~/dotfiles/install.sh'

// Leído del catálogo, no escrito a mano: es la misma regla que gcx aplica a los
// mensajes de estado. Un 41 tecleado aquí envejece al primer brew nuevo y nadie
// lo nota. La línea de symlinks no lleva cifra por el mismo motivo: el número de
// enlaces no sale de ninguna fuente que este componente pueda leer.
const FORMULAS = herramientas.filter((h) => h.entradas.some((e) => e.tipo === 'brew')).length

const SALIDA = [
  { texto: '✔ detect · macOS arm64', color: 'text-green' },
  { texto: `✔ packages · ${FORMULAS} fórmulas`, color: 'text-green' },
  { texto: '✔ binaries · sha256 verificados', color: 'text-green' },
  { texto: '✔ symlinks · configs enlazadas', color: 'text-green' },
]

export function Hero() {
  const [escrito, setEscrito] = useState('')
  const [listo, setListo] = useState(false)

  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduce) {
      setEscrito(COMANDO)
      setListo(true)
      return
    }
    let i = 0
    const id = setInterval(() => {
      i += 1
      setEscrito(COMANDO.slice(0, i))
      if (i >= COMANDO.length) {
        clearInterval(id)
        setListo(true)
      }
    }, 22)
    return () => clearInterval(id)
  }, [])

  return (
    <section className="mx-auto max-w-5xl px-6 pt-24 pb-20 sm:pt-32">
      <p className="font-mono text-xs uppercase tracking-[0.2em] text-overlay0">
        SRE 2026 · macOS + Debian
      </p>
      <h1 className="mt-5 text-5xl font-bold leading-[1.05] tracking-tight sm:text-6xl">
        Toda la caja,
        <br />
        <span className="text-teal">un comando</span>
      </h1>
      <p className="mt-6 max-w-xl text-lg text-subtext0">
        Terminal, editor, cloud y Kubernetes reproducibles en cualquier máquina. Cinco
        presets, dos sistemas operativos y checksums verificados en cada binario.
      </p>

      <div className="mt-10">
        <TerminalWindow titulo="~/dotfiles">
          <p className="break-all text-text">
            <span className="text-teal">❯ </span>
            {escrito}
            {!listo && <span className="ml-0.5 inline-block w-2 animate-pulse bg-text">&nbsp;</span>}
          </p>
          {listo &&
            SALIDA.map((l) => (
              <p key={l.texto} className={`mt-1 ${l.color}`}>
                {l.texto}
              </p>
            ))}
        </TerminalWindow>
      </div>

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <CopyButton texto={COMANDO} />
        <a
          href="#presets"
          className="rounded-md bg-lavender px-4 py-1.5 text-sm font-semibold text-crust transition hover:bg-teal"
        >
          Ver los presets
        </a>
        <a
          href="https://github.com/kr0nicas/dotfiles"
          className="rounded-md border border-surface1 px-4 py-1.5 text-sm text-subtext0 transition hover:border-lavender hover:text-lavender"
        >
          Repo en GitHub
        </a>
      </div>
    </section>
  )
}
```

- [ ] **Paso 5: Montarlo en la portada**

`web/src/app/page.tsx`:

```tsx
import { Hero } from '@/components/Hero'

export default function Home() {
  return (
    <main>
      <Hero />
    </main>
  )
}
```

- [ ] **Paso 6: Comprobar en el navegador**

```bash
cd web && npm run dev
```

Abre `http://localhost:3000/dotfiles`. Comprueba tres cosas: el comando se teclea solo, `copiar` cambia a `✓ copiado`, y con "Reducir movimiento" activado en el sistema el comando sale entero de golpe.

- [ ] **Paso 7: Commit**

```bash
git add web/src/components/ web/src/app/page.tsx
git commit -m 'feat(web): hero con terminal que se autoescribe

TerminalWindow es el chrome que reutilizan presets y capturas, asi que sale ya
como componente propio en vez de inline en el hero.

La animacion consulta prefers-reduced-motion antes de arrancar: con la
preferencia activa el comando aparece entero, que es lo unico util para quien
la tiene puesta.'
```

---

### Task 8: Highlights y selector de presets

**Ficheros:**
- Crear: `web/src/components/Highlights.tsx`, `web/src/components/PresetSelector.tsx`
- Modificar: `web/src/app/page.tsx`

**Interfaces:**
- Consume: `presets`, `cuentaDePreset` de `@/data/herramientas`; `SectionHeading` y `TerminalWindow` de la Task 7.
- Produce: `<Highlights />` y `<PresetSelector />`, ambos sin props.

- [ ] **Paso 1: `Highlights`**

```tsx
import { SectionHeading } from './SectionHeading'

const PUNTOS = [
  {
    titulo: 'Cross-platform de verdad',
    texto:
      'macOS con Homebrew y Debian con apt más binarios de GitHub Releases. No es un dotfiles de Mac con un if suelto.',
    acento: 'text-blue',
  },
  {
    titulo: 'Cinco presets',
    texto:
      'VPS, contenedor, nodo de Kubernetes, caja de agente y mínimo. Cada uno enciende los módulos que esa máquina va a usar.',
    acento: 'text-mauve',
  },
  {
    titulo: 'Checksums verificados',
    texto:
      'Cada binario que baja de GitHub Releases se comprueba contra el sha256 del propio release, y avisa cuando el proyecto no publica ninguno.',
    acento: 'text-green',
  },
  {
    titulo: 'Arnés de reglas',
    texto:
      'Hooks de git y CI que validan sintaxis, shellcheck a nivel info, convención de commits y el CHANGELOG generado.',
    acento: 'text-peach',
  },
  {
    titulo: 'Catppuccin Mocha en todo',
    texto:
      'Neovim, tmux, starship, delta y esta misma página comparten paleta. Cambiar de máquina no cambia de entorno.',
    acento: 'text-pink',
  },
]

export function Highlights() {
  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="highlights" eyebrow="Por qué" titulo="Qué lo hace distinto" />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {PUNTOS.map((p) => (
          <div
            key={p.titulo}
            className="rounded-lg border border-surface0 bg-mantle p-5 transition hover:border-surface1"
          >
            <h3 className={`font-semibold ${p.acento}`}>{p.titulo}</h3>
            <p className="mt-2 text-sm leading-relaxed text-subtext0">{p.texto}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
```

- [ ] **Paso 2: `PresetSelector`**

El recuento sale de `cuentaDePreset`, no de una constante: si mañana añades un `brew`, el número sube solo.

```tsx
'use client'

import { useState } from 'react'
import { presets, cuentaDePreset } from '@/data/herramientas'
import { SectionHeading } from './SectionHeading'
import { TerminalWindow } from './TerminalWindow'

const DESCRIPCION: Record<string, string> = {
  '--minimal': 'Solo el entorno de terminal. Sin cloud, sin Kubernetes, sin apps de escritorio.',
  '--vps': 'Servidor con trabajo de cloud: base más las CLIs de AWS, Azure, GCP y OpenTofu.',
  '--container': 'Imagen de Docker. Ultra-mínimo: lo justo para que la shell sea usable.',
  '--k8s-node': 'Nodo de Kubernetes: base, cloud y todo el instrumental de clúster.',
  '--agent': 'Caja de agente. Salta los editores y solo enlaza ~/.claude, porque una zsh no interactiva nunca lee el resto.',
}

const MODULOS = [
  { clave: 'cloud', etiqueta: 'cloud' },
  { clave: 'k8s', etiqueta: 'k8s' },
  { clave: 'gui', etiqueta: 'gui' },
] as const

export function PresetSelector() {
  const [activo, setActivo] = useState(presets[0]?.flag ?? '')
  const preset = presets.find((p) => p.flag === activo) ?? presets[0]

  if (!preset) return null

  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="presets" eyebrow="Presets" titulo="Una caja, cinco formas">
        Los presets no eligen herramientas sueltas: encienden módulos. El recuento sale
        del catálogo, así que no puede desfasarse del instalador.
      </SectionHeading>

      <div className="flex flex-wrap gap-2" role="tablist" aria-label="Presets disponibles">
        {presets.map((p) => (
          <button
            key={p.flag}
            role="tab"
            aria-selected={p.flag === activo}
            onClick={() => setActivo(p.flag)}
            className={`rounded-md border px-3 py-1.5 font-mono text-sm transition ${
              p.flag === activo
                ? 'border-lavender bg-lavender/10 text-lavender'
                : 'border-surface0 text-subtext0 hover:border-surface1 hover:text-text'
            }`}
          >
            {p.flag}
          </button>
        ))}
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <TerminalWindow titulo="instalación">
          <p>
            <span className="text-teal">❯ </span>
            <span className="text-text">./install.sh {preset.flag}</span>
          </p>
          <p className="mt-3 text-subtext0">
            módulos: <span className="text-green">base=ON</span>
            {MODULOS.map((m) => (
              <span key={m.clave}>
                {', '}
                <span className={preset[m.clave] ? 'text-green' : 'text-overlay0'}>
                  {m.etiqueta}={preset[m.clave] ? 'ON' : 'OFF'}
                </span>
              </span>
            ))}
          </p>
          <p className="mt-3 text-peach">
            ≈ {cuentaDePreset(preset)} herramientas
          </p>
        </TerminalWindow>

        <div className="rounded-lg border border-surface0 bg-mantle p-6">
          <h3 className="font-mono text-lg text-lavender">{preset.flag}</h3>
          <p className="mt-3 leading-relaxed text-subtext0">
            {DESCRIPCION[preset.flag] ?? 'Preset del instalador.'}
          </p>
        </div>
      </div>
    </section>
  )
}
```

> Si añades un preset nuevo a `install.sh` y no le pones entrada en `DESCRIPCION`, la web lo muestra igual con un texto genérico. Es deliberado: el selector nunca oculta un preset que existe.

- [ ] **Paso 3: Montarlos en la portada**

```tsx
import { Hero } from '@/components/Hero'
import { Highlights } from '@/components/Highlights'
import { PresetSelector } from '@/components/PresetSelector'

export default function Home() {
  return (
    <main>
      <Hero />
      <Highlights />
      <PresetSelector />
    </main>
  )
}
```

- [ ] **Paso 4: Comprobar**

```bash
cd web && npm run build
```

Esperado: build limpio. Con `npm run dev`, comprueba que aparecen los cinco presets, que `--agent` muestra `cloud=ON, k8s=ON, gui=OFF`, y que el recuento cambia al pulsar `--minimal`.

- [ ] **Paso 5: Commit**

```bash
git add web/src/components/Highlights.tsx web/src/components/PresetSelector.tsx web/src/app/page.tsx
git commit -m 'feat(web): highlights y selector de presets

El recuento de herramientas sale de cuentaDePreset, no de una constante: es la
misma regla que gcx aplica a los mensajes de estado. Un numero tecleado a mano
aqui envejeceria al primer brew nuevo y nadie lo notaria.'
```

---

### Task 9: Catálogo en `/stack`

**Ficheros:**
- Crear: `web/src/components/ToolCard.tsx`, `web/src/components/FilterBar.tsx`, `web/src/components/Catalogo.tsx`, `web/src/app/stack/page.tsx`

**Interfaces:**
- Consume: `herramientas`, `categorias` de `@/data/herramientas`; el tipo `Herramienta`.
- Produce: la ruta `/stack`.

**Aviso de `output: 'export'`:** `useSearchParams` obliga a envolver el componente en `<Suspense>`. Sin eso el build falla con *"useSearchParams() should be wrapped in a suspense boundary"* — y falla en `next build`, no en `dev`.

- [ ] **Paso 1: `ToolCard`**

```tsx
import type { Herramienta } from '@/data/types'

const COLOR_MODULO: Record<string, string> = {
  base: 'border-green/40 text-green',
  cloud: 'border-peach/40 text-peach',
  k8s: 'border-blue/40 text-blue',
  gui: 'border-pink/40 text-pink',
}

export function ToolCard({ h }: { h: Herramienta }) {
  return (
    <a
      href={h.url}
      target="_blank"
      rel="noreferrer"
      className="flex flex-col rounded-lg border border-surface0 bg-mantle p-4 transition hover:border-lavender"
    >
      <div className="flex items-start justify-between gap-3">
        <h3 className="font-mono font-semibold text-text">{h.nombre}</h3>
        <div className="flex shrink-0 gap-1">
          {h.modulos.map((m) => (
            <span
              key={m}
              className={`rounded border px-1.5 py-0.5 font-mono text-[10px] ${COLOR_MODULO[m] ?? 'border-surface1 text-overlay0'}`}
            >
              {m}
            </span>
          ))}
        </div>
      </div>
      <p className="mt-2 flex-1 text-sm leading-relaxed text-subtext0">{h.descripcion}</p>
      <p className="mt-3 font-mono text-[11px] text-overlay0">
        {h.plataformas.includes('macos') && 'macOS'}
        {h.plataformas.length === 2 && ' · '}
        {h.plataformas.includes('linux') && 'Linux'}
      </p>
    </a>
  )
}
```

- [ ] **Paso 2: `FilterBar`**

```tsx
'use client'

import type { Modulo, Plataforma } from '@/data/types'

export const MODULOS = ['base', 'cloud', 'k8s', 'gui'] as const
export const PLATAFORMAS = ['macos', 'linux'] as const

export interface Filtros {
  q: string
  modulo: Modulo | ''
  plataforma: Plataforma | ''
  categoria: string
}

// La querystring es entrada de fuera: `?m=loquesea` tiene que degradar a "todos"
// y no a "ningún resultado", que parecería el buscador roto. Estas dos guardas
// son además lo que hace que los `includes` de Catalogo typecheen sin castear.
export function comoModulo(v: string): Modulo | '' {
  return (MODULOS as readonly string[]).includes(v) ? (v as Modulo) : ''
}

export function comoPlataforma(v: string): Plataforma | '' {
  return (PLATAFORMAS as readonly string[]).includes(v) ? (v as Plataforma) : ''
}

export function FilterBar({
  filtros,
  categorias,
  onCambio,
  total,
}: {
  filtros: Filtros
  categorias: string[]
  onCambio: (parcial: Partial<Filtros>) => void
  total: number
}) {
  const select = 'rounded-md border border-surface0 bg-mantle px-3 py-2 text-sm text-subtext0'

  return (
    <div className="sticky top-0 z-10 -mx-6 mb-8 border-b border-surface0 bg-base/95 px-6 py-4 backdrop-blur">
      <div className="flex flex-wrap items-center gap-3">
        <input
          type="search"
          value={filtros.q}
          onChange={(e) => onCambio({ q: e.target.value })}
          placeholder="Buscar herramienta…"
          aria-label="Buscar herramienta"
          className="min-w-52 flex-1 rounded-md border border-surface0 bg-mantle px-3 py-2 font-mono text-sm text-text placeholder:text-overlay0 focus:border-lavender focus:outline-none"
        />
        <select
          value={filtros.plataforma}
          onChange={(e) => onCambio({ plataforma: comoPlataforma(e.target.value) })}
          aria-label="Filtrar por plataforma"
          className={select}
        >
          <option value="">Toda plataforma</option>
          <option value="macos">macOS</option>
          <option value="linux">Linux</option>
        </select>
        <select
          value={filtros.modulo}
          onChange={(e) => onCambio({ modulo: comoModulo(e.target.value) })}
          aria-label="Filtrar por módulo"
          className={select}
        >
          <option value="">Todo módulo</option>
          {MODULOS.map((m) => (
            <option key={m} value={m}>
              {m}
            </option>
          ))}
        </select>
        <select
          value={filtros.categoria}
          onChange={(e) => onCambio({ categoria: e.target.value })}
          aria-label="Filtrar por categoría"
          className={select}
        >
          <option value="">Toda categoría</option>
          {categorias.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <span className="font-mono text-sm text-overlay0" aria-live="polite">
          {total} resultado{total === 1 ? '' : 's'}
        </span>
      </div>
    </div>
  )
}
```

- [ ] **Paso 3: `Catalogo`, con el estado en la querystring**

```tsx
'use client'

import { useRouter, useSearchParams } from 'next/navigation'
import { useMemo } from 'react'
import { herramientas, categorias } from '@/data/herramientas'
import { FilterBar, comoModulo, comoPlataforma, type Filtros } from './FilterBar'
import { ToolCard } from './ToolCard'

function normalizar(s: string) {
  return s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
}

export function Catalogo() {
  const router = useRouter()
  const params = useSearchParams()

  const filtros: Filtros = {
    q: params.get('q') ?? '',
    modulo: comoModulo(params.get('m') ?? ''),
    plataforma: comoPlataforma(params.get('p') ?? ''),
    categoria: params.get('c') ?? '',
  }

  function onCambio(parcial: Partial<Filtros>) {
    const siguiente = { ...filtros, ...parcial }
    const qs = new URLSearchParams()
    if (siguiente.q) qs.set('q', siguiente.q)
    if (siguiente.modulo) qs.set('m', siguiente.modulo)
    if (siguiente.plataforma) qs.set('p', siguiente.plataforma)
    if (siguiente.categoria) qs.set('c', siguiente.categoria)
    router.replace(qs.size ? `?${qs}` : '/stack', { scroll: false })
  }

  const visibles = useMemo(() => {
    const q = normalizar(filtros.q)
    return herramientas.filter((h) => {
      if (filtros.modulo && !h.modulos.includes(filtros.modulo)) return false
      if (filtros.plataforma && !h.plataformas.includes(filtros.plataforma)) return false
      if (filtros.categoria && h.categoria !== filtros.categoria) return false
      if (!q) return true
      return normalizar(`${h.nombre} ${h.descripcion} ${h.categoria}`).includes(q)
    })
  }, [filtros.q, filtros.modulo, filtros.plataforma, filtros.categoria])

  return (
    <div className="mx-auto max-w-6xl px-6 py-16">
      <p className="font-mono text-xs uppercase tracking-[0.2em] text-overlay0">Catálogo</p>
      <h1 className="mt-3 text-4xl font-bold tracking-tight">El stack completo</h1>
      <p className="mt-4 max-w-2xl text-subtext0">
        Todo lo que instala el repo, derivado de los Brewfiles, de{' '}
        <code className="font-mono text-teal">lib/binaries.sh</code> y del bloque apt. Ni
        un nombre está escrito a mano.
      </p>

      <div className="mt-10">
        <FilterBar
          filtros={filtros}
          categorias={categorias}
          onCambio={onCambio}
          total={visibles.length}
        />

        {visibles.length === 0 ? (
          <p className="py-16 text-center font-mono text-subtext0">
            Nada coincide con esos filtros.
          </p>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {visibles.map((h) => (
              <ToolCard key={h.id} h={h} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Paso 4: La ruta, con su `Suspense`**

`web/src/app/stack/page.tsx`:

```tsx
import { Suspense } from 'react'
import { Catalogo } from '@/components/Catalogo'

export const metadata = {
  title: 'El stack completo — Dotfiles SRE 2026',
  description: 'Catálogo filtrable de todas las herramientas que instala el repo.',
}

export default function StackPage() {
  return (
    // useSearchParams obliga a este Suspense. Sin él, `next build` falla — y
    // `next dev` no, que es la peor forma de descubrirlo.
    <Suspense fallback={<div className="mx-auto max-w-6xl px-6 py-16">Cargando…</div>}>
      <Catalogo />
    </Suspense>
  )
}
```

- [ ] **Paso 5: Comprobar que exporta**

```bash
cd web && npm run build && ls out/stack/index.html
```

Esperado: build limpio y el fichero existe. Con `npm run dev`, comprueba en `http://localhost:3000/dotfiles/stack`: escribir en el buscador cambia la URL, recargar con `?m=k8s` mantiene el filtro, y buscar "busqueda" encuentra entradas escritas con tilde.

- [ ] **Paso 6: Commit**

```bash
git add web/src/components/ToolCard.tsx web/src/components/FilterBar.tsx web/src/components/Catalogo.tsx web/src/app/stack/
git commit -m 'feat(web): catalogo filtrable en /stack

El estado vive en la querystring para que un filtro sea enlazable. Eso obliga
a envolver el componente en Suspense: sin el, next build falla y next dev no,
que es la peor forma de enterarse.

La busqueda normaliza tildes: sin eso, "diagnostico" no encuentra
"diagnostico" escrito con tilde y el buscador parece roto.'
```

---

### Task 10: Capturas, `gcx`, teaser y footer

**Ficheros:**
- Crear: `web/src/components/Capturas.tsx`, `web/src/components/Gcx.tsx`, `web/src/components/StackTeaser.tsx`, `web/src/components/Footer.tsx`, `web/public/screenshots/README.md`
- Modificar: `web/src/app/page.tsx`

**Interfaces:**
- Consume: `TerminalWindow`, `SectionHeading`; `herramientas` para el recuento del teaser.
- Produce: la portada completa.

- [ ] **Paso 1: El README de las capturas**

`web/public/screenshots/README.md` — es lo que le dice al humano qué falta:

```markdown
# Capturas del escaparate

Cinco PNG, todas en **1600×1000** (relación 8:5) y en tema Catppuccin Mocha.
`Capturas.tsx` las referencia por nombre; mientras no existan, el sitio pinta
un marcador de posición en su hueco.

| Fichero | Qué capturar |
|---|---|
| `nvim.png` | Neovim con un fichero abierto, telescope o el árbol de oil visible |
| `tmux.png` | Sesión con dos paneles y la barra de estado a la vista |
| `starship.png` | El prompt en un repo con cambios sin commitear |
| `k9s.png` | k9s en la vista de pods de un clúster |
| `gcx.png` | El picker de `gcx` con varias configuraciones listadas |

Recórtalas sin la barra de título del sistema operativo: el componente ya pone
su propio chrome de terminal alrededor.
```

- [ ] **Paso 2: `Capturas`, con hueco visible cuando falta el PNG**

Los ficheros no existen todavía, así que se usa `<img>` con `onError` para caer al marcador. No uses `next/image`: con `unoptimized` no aporta nada y complica el fallback.

```tsx
'use client'

import { useState } from 'react'
import { SectionHeading } from './SectionHeading'
import { TerminalWindow } from './TerminalWindow'

const CAPTURAS = [
  { archivo: 'nvim.png', titulo: 'nvim', pie: 'Neovim con LSP, telescope y Catppuccin' },
  { archivo: 'tmux.png', titulo: 'tmux', pie: 'Prefijo en C-a, navegación compartida con nvim' },
  { archivo: 'starship.png', titulo: 'starship', pie: 'Prompt con estado de git, cloud y k8s' },
  { archivo: 'k9s.png', titulo: 'k9s', pie: 'El clúster sin escribir kubectl' },
  { archivo: 'gcx.png', titulo: 'gcx', pie: 'Cambiar de cuenta y proyecto de GCP con fzf' },
]

function Captura({ archivo, titulo, pie }: { archivo: string; titulo: string; pie: string }) {
  const [falla, setFalla] = useState(false)

  return (
    <figure>
      <TerminalWindow titulo={titulo}>
        {falla ? (
          <div className="flex h-48 items-center justify-center rounded border border-dashed border-surface1 text-center text-xs text-overlay0">
            Falta <code className="mx-1 text-peach">public/screenshots/{archivo}</code>
          </div>
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={`/dotfiles/screenshots/${archivo}`}
            alt={pie}
            width={1600}
            height={1000}
            className="w-full rounded"
            onError={() => setFalla(true)}
          />
        )}
      </TerminalWindow>
      <figcaption className="mt-3 text-sm text-subtext0">{pie}</figcaption>
    </figure>
  )
}

export function Capturas() {
  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="capturas" eyebrow="El entorno" titulo="Así se ve" />
      <div className="grid gap-8 lg:grid-cols-2">
        {CAPTURAS.map((c) => (
          <Captura key={c.archivo} {...c} />
        ))}
      </div>
    </section>
  )
}
```

- [ ] **Paso 3: `Gcx`**

```tsx
import { SectionHeading } from './SectionHeading'
import { TerminalWindow } from './TerminalWindow'

export function Gcx() {
  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="gcx" eyebrow="Pieza propia" titulo="gcx — saltar de cuenta en GCP">
        Sustituyó a cuatro aliases que imprimían con <code className="font-mono text-teal">echo</code>{' '}
        una cuenta escrita a mano que ya no coincidía con la configuración que activaban.
        Ahora cada dato se lee de <code className="font-mono text-teal">gcloud</code> en el momento.
      </SectionHeading>

      <div className="grid gap-6 lg:grid-cols-2">
        <TerminalWindow titulo="gcx">
          <p>
            <span className="text-teal">❯ </span>
            <span className="text-text">gcx</span>
          </p>
          <p className="mt-2 text-subtext0">{'>'} personal   ochoa.j@gmail.com   mi-proyecto</p>
          <p className="text-overlay0">  trabajo    j.ochoa@empresa    prod-eu</p>
          <p className="text-overlay0">  cliente    sre@cliente.io     staging</p>
          <p className="mt-3">
            <span className="text-teal">❯ </span>
            <span className="text-text">gcx p</span>
            <span className="text-overlay0"> · proyectos de la cuenta activa (con caché)</span>
          </p>
        </TerminalWindow>

        <div className="space-y-3">
          {[
            ['gcx', 'Picker de configuraciones: cuenta y proyecto'],
            ['gcx p [-r]', 'Proyectos de la cuenta activa; -r refresca la caché'],
            ['gcx use <config>', 'Activa una configuración por nombre'],
            ['gcx who', 'Config, cuenta y proyecto activos'],
          ].map(([cmd, desc]) => (
            <div key={cmd} className="rounded-lg border border-surface0 bg-mantle p-4">
              <code className="font-mono text-sm text-lavender">{cmd}</code>
              <p className="mt-1 text-sm text-subtext0">{desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
```

- [ ] **Paso 4: `StackTeaser` y `Footer`**

```tsx
import Link from 'next/link'
import { herramientas } from '@/data/herramientas'

export function StackTeaser() {
  const muestra = herramientas.slice(0, 24)

  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <div className="rounded-xl border border-surface0 bg-mantle p-8">
        <h2 className="text-2xl font-bold tracking-tight">
          {herramientas.length} herramientas, ninguna escrita a mano
        </h2>
        <p className="mt-3 max-w-2xl text-subtext0">
          El catálogo se deriva de los Brewfiles, de{' '}
          <code className="font-mono text-teal">lib/binaries.sh</code> y del bloque apt del
          instalador. Si el repo cambia y el catálogo no, el CI se pone rojo.
        </p>
        <div className="mt-6 flex flex-wrap gap-2">
          {muestra.map((h) => (
            <span
              key={h.id}
              className="rounded border border-surface1 px-2 py-1 font-mono text-xs text-subtext0"
            >
              {h.nombre}
            </span>
          ))}
          <span className="px-2 py-1 font-mono text-xs text-overlay0">
            +{herramientas.length - muestra.length} más
          </span>
        </div>
        <Link
          href="/stack"
          className="mt-8 inline-block rounded-md bg-lavender px-4 py-2 text-sm font-semibold text-crust transition hover:bg-teal"
        >
          Ver el catálogo completo →
        </Link>
      </div>
    </section>
  )
}
```

```tsx
const ENLACES = [
  ['Repositorio', 'https://github.com/kr0nicas/dotfiles'],
  ['CHANGELOG', 'https://github.com/kr0nicas/dotfiles/blob/main/CHANGELOG.md'],
  ['Chuleta', 'https://github.com/kr0nicas/dotfiles/blob/main/CHEAT_CODES.md'],
  ['Diseños y planes', 'https://github.com/kr0nicas/dotfiles/tree/main/docs'],
]

export function Footer() {
  return (
    <footer className="border-t border-surface0 bg-mantle">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-6 py-10">
        <p className="font-mono text-sm text-overlay0">
          dotfiles · Jorge Ochoa (kr0nicas) · MIT
        </p>
        <nav className="flex flex-wrap gap-4">
          {ENLACES.map(([texto, href]) => (
            <a
              key={href}
              href={href}
              className="text-sm text-subtext0 transition hover:text-lavender"
            >
              {texto}
            </a>
          ))}
        </nav>
      </div>
    </footer>
  )
}
```

- [ ] **Paso 5: Portada completa**

```tsx
import { Hero } from '@/components/Hero'
import { Highlights } from '@/components/Highlights'
import { PresetSelector } from '@/components/PresetSelector'
import { Capturas } from '@/components/Capturas'
import { Gcx } from '@/components/Gcx'
import { StackTeaser } from '@/components/StackTeaser'
import { Footer } from '@/components/Footer'

export default function Home() {
  return (
    <>
      <main>
        <Hero />
        <Highlights />
        <PresetSelector />
        <Capturas />
        <Gcx />
        <StackTeaser />
      </main>
      <Footer />
    </>
  )
}
```

- [ ] **Paso 6: Comprobar**

```bash
cd web && npm run build
```

Esperado: build limpio. En `npm run dev`, las cinco capturas muestran el marcador "Falta public/screenshots/…" —correcto mientras no existan los PNG— y el enlace del teaser lleva a `/dotfiles/stack`.

- [ ] **Paso 7: Commit**

```bash
git add web/src/components/ web/src/app/page.tsx web/public/screenshots/
git commit -m 'feat(web): capturas, gcx, teaser del stack y footer

Las capturas caen a un marcador que nombra el fichero que falta en vez de a un
hueco mudo o a un 404 en consola: el sitio se publica util desde el primer dia
y dice exactamente que PNG hay que anadir.'
```

---

### Task 11: Workflow de Pages y documentación

**Ficheros:**
- Crear: `.github/workflows/web.yml`
- Modificar: `CLAUDE.md`, `README.md`, `docs/README.md`

**Interfaces:**
- Consume: los scripts `check` y `build` de `web/package.json`.
- Produce: el despliegue.

- [ ] **Paso 1: El workflow**

Dispara también en los ficheros fuente del catálogo: así, tocar un Brewfile sin regenerar el JSON rompe la PR, que es el único momento útil para enterarse.

```yaml
name: Web

on:
  push:
    branches: [main]
    paths:
      - 'web/**'
      - 'Brewfile*'
      - 'lib/binaries.sh'
      - 'lib/packages.sh'
      - 'install.sh'
      - '.github/workflows/web.yml'
  pull_request:
    paths:
      - 'web/**'
      - 'Brewfile*'
      - 'lib/binaries.sh'
      - 'lib/packages.sh'
      - 'install.sh'
      - '.github/workflows/web.yml'
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: pages-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    name: Build y guardia del catálogo
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: npm
          cache-dependency-path: web/package-lock.json

      - name: Instalar dependencias
        working-directory: web
        run: npm ci

      - name: Tests de los extractores
        working-directory: web
        run: npm test

      # La guardia va antes del build y es la que de verdad importa: compara el
      # tools.generated.json versionado contra lo que el repo declara hoy, en
      # las dos direcciones. Si alguien añade un brew sin regenerarlo, aquí se
      # cae — no en producción, con el catálogo mintiendo.
      - name: Guardia del catálogo
        working-directory: web
        run: npm run check

      - name: Build estático
        working-directory: web
        run: npx next build

      - uses: actions/upload-pages-artifact@v3
        if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
        with:
          path: web/out

  deploy:
    name: Desplegar en Pages
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    needs: build
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

- [ ] **Paso 2: Versionar el lockfile**

`npm ci` lo exige y el paso de caché lo referencia.

```bash
cd web && npm install && git add web/package-lock.json && git status --short web/
```

Esperado: `package-lock.json` aparece como añadido.

- [ ] **Paso 3: Documentar `web/` en `CLAUDE.md`**

Añade esta sección nueva **inmediatamente después** de la sección
`### rtk (Rust Token Killer)` y antes de `### gcx — switcher de cuentas y
proyectos de GCP`. No toques la tabla de `scripts/ y documentos sueltos`:
`web/` no es un script suelto, es un subsistema con sección propia.

```markdown
### `web/` — el escaparate

Sitio en Next.js 15 con `output: 'export'`, desplegado en GitHub Pages por
`.github/workflows/web.yml`. Vive en el repo, así que comparte PRs y hooks:
el ámbito de commit es `web`.

- **El catálogo de herramientas no se escribe a mano.** `web/scripts/extract-*.mjs`
  parsea `Brewfile*`, `lib/binaries.sh`, el bloque apt de `lib/packages.sh` y los
  presets de `install.sh`, y escribe `web/src/data/tools.generated.json`, que **se
  versiona**. A mano solo va `tools.curated.json`: nombre de presentación,
  categoría, descripción y URL.
- **`check-tools.mjs` es la guardia y falla en las dos direcciones**: una
  herramienta del repo sin ficha curada, y una ficha que declara algo que el repo
  ya no instala. Corre en `npm run build` y en CI, con el mismo papel que
  `scripts/changelog.sh --check`. **Si añades un `brew`, corre `npm run extract` y
  commitea el JSON**, o la PR se pone roja.
- **`lib/binaries.sh` declara herramientas de tres formas y el parser caza las
  tres.** `install_if_missing "x"` es la mayoría, pero `kubectl`, `helm`,
  `kubectx`, `kubens` y `tofu` van por bloques `if ! command -v x` a medida.
  Mirar solo la primera forma deja fuera las cinco más visibles del catálogo sin
  dar ningún error. Si tocas la forma de esas declaraciones, mira
  `extract-binaries.mjs`.
- **Los mínimos por fuente de `check-tools.mjs` existen porque el parser es regex
  sobre bash**: si deja de casar, no falla — publica un catálogo mutilado. Bajar
  un mínimo para poner verde un build rojo es desactivar la guardia.
- **`basePath: '/dotfiles'`** es obligatorio: es una *project page*. Sin él, los
  assets dan 404 en producción y en local no, que es la peor forma de descubrirlo.
- El estado de los filtros de `/stack` vive en la querystring, así que
  `useSearchParams` obliga a un `<Suspense>`. Sin él **`next build` falla y
  `next dev` no**.
- Comandos, siempre desde `web/`: `npm run dev`, `npm test` (extractores),
  `npm run extract` (regenerar el JSON), `npm run check` (guardia),
  `npm run build` (guardia + export a `web/out/`).
```

- [ ] **Paso 4: Documentar en `README.md`**

En el árbol de `## 🗂️ Estructura de archivos`, añade esta línea junto a las
demás entradas de primer nivel (respeta la alineación de comentarios del bloque):

```
├── web/                    # Escaparate en Next.js (GitHub Pages)
```

Y añade esta sección completa **entre** `## 🤖 Claude Code` y `## 🔧 Git`.
Acuérdate de añadirla también a la `## 📑 Tabla de contenidos` del principio,
en la posición que le corresponde:

```markdown
## 🌐 Escaparate web

`web/` — sitio en Next.js publicado en GitHub Pages que enseña el entorno y deja
navegar el catálogo completo de herramientas.

El catálogo **se deriva de este repo**: un extractor lee los Brewfiles,
`lib/binaries.sh` y el bloque apt, y una guardia rompe el CI si el catálogo y el
instalador dejan de coincidir. Si añades una herramienta:

```bash
cd web && npm run extract   # regenera tools.generated.json
# añade su ficha en web/src/data/tools.curated.json
npm run check               # confirma que cuadra
```
```

- [ ] **Paso 5: Actualizar `docs/README.md`**

En la tabla de `specs/`, la fila de `2026-08-09-web-escaparate-design.md` dice todavía **Sin implementar**. Cámbiala a:

```
| `2026-08-09-web-escaparate-design.md` | El repo solo se explica en 554 líneas de README: nada que enseñe cómo se ve el entorno ni que deje navegar las ~130 herramientas repartidas entre cuatro Brewfiles y dos ficheros de `lib/` | `web/`, sección **`web/`** de `CLAUDE.md` |
```

Y añade el plan a la tabla de `plans/`:

```
| `2026-08-09-web-escaparate.md` | 2795 | web-escaparate | PR #NN |
```

Sustituye `#NN` por el número real que devuelva `gh pr create` en el Paso 9.

Y en la cabecera del índice, cambia `Nueve documentos, ~4.600 líneas.` por
`Diez documentos, ~7.400 líneas.`. Confirma la cifra antes de escribirla:

```bash
wc -l docs/README.md docs/superpowers/specs/*.md docs/superpowers/plans/*.md docs/reports/*.md | tail -1
```

Además, la fila de este spec deja de ser una excepción, así que comprueba si
queda alguna otra marcada **sin implementar**; si no queda ninguna, revierte el
párrafo de la cabecera a su forma anterior (`**Todo lo que hay aquí es
histórico.**`, sin la frase sobre la excepción).

- [ ] **Paso 6: Comprobar que el workflow es válido**

```bash
cd web && npm ci && npm test && npm run check && npx next build
```

Esperado: los cuatro pasos en verde — es exactamente lo que hará el runner.

- [ ] **Paso 7: Commit**

Dos commits, porque tocan cosas distintas:

```bash
git add .github/workflows/web.yml web/package-lock.json
git commit -m 'ci(ci): publicar el escaparate en GitHub Pages

Dispara tambien en Brewfile*, lib/binaries.sh, lib/packages.sh e install.sh, no
solo en web/. Tocar un Brewfile sin regenerar el catalogo tiene que romper la
PR: es el unico momento en que sirve enterarse.'
```

```bash
git add CLAUDE.md README.md docs/README.md
git commit -m 'docs(docs): documentar el escaparate web

Un directorio de primer nivel sin declarar en CLAUDE.md repite el fallo del
indice desactualizado que docs/README.md avisa de no cometer.'
```

- [ ] **Paso 8: Regenerar el CHANGELOG, en su propio commit**

Último paso antes del push. **Aislado**, sin encadenar nada detrás:

```bash
./scripts/changelog.sh
```

```bash
git add CHANGELOG.md
git commit -m 'chore(repo): regenerar CHANGELOG'
```

Comprueba que existe: `git log --oneline -1`.

- [ ] **Paso 9: PR**

```bash
git push -u origin HEAD
```

```bash
gh pr create --fill
```

- [ ] **Paso 10: Activar Pages (manual, una sola vez)**

En GitHub: **Settings → Pages → Source: GitHub Actions**. Sin esto el job `deploy` falla con *"Pages site not found"* por mucho que el build esté en verde. Tras el merge a `main`, el sitio queda en `https://kr0nicas.github.io/dotfiles/`.

---

## Notas para quien ejecute esto

- **El orden importa entre las Tasks 2–6.** El checker de la 6 depende del orquestador de la 5, que depende de los cuatro parsers. No las reordenes.
- **Las Tasks 7–10 son independientes entre sí** salvo por los componentes que la 7 produce (`TerminalWindow`, `SectionHeading`, `CopyButton`). Si se paralelizan, la 7 va primero.
- **La Task 6 Paso 3 es la más larga del plan**: escribir ~140 descripciones a mano. No la trocees en varios commits; el checker no pasa hasta que están todas, así que el commit intermedio dejaría el build roto.
- **Si un extractor no ve una herramienta, no falla: la omite.** Por eso cada tarea de parser termina comprobando contra los ficheros reales y no solo contra fixtures.
