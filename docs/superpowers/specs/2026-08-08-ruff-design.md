# Migrar el stack de Python de flake8 + black a ruff

Fecha: 2026-08-08
Estado: diseño aprobado

## Problema

Abrir cualquier `.py` en Neovim lanza `Error running flake8: ENOENT`. El diagnóstico
inicial se quedó corto: el fallo no es de un solo linter, son tres defectos apilados.

**1. `flake8` está configurado pero no existe en ninguna parte.** `nvim-lint` lo declara
en `config/nvim/lua/plugins/lsp.lua:147`, pero `flake8` no aparece en `Brewfile`,
`Brewfile.cloud`, `Brewfile.k8s`, `Brewfile.gui` ni en `lib/binaries.sh`. Nunca se
instaló en ninguna máquina. El ENOENT lleva ahí desde que se escribió esa línea.

**2. El formateo también está roto, en silencio.** `conform.nvim` declara `black` en
`lsp.lua:130` y `Brewfile:48` sí lo lista, pero `black` **no está instalado** en esta
máquina. A diferencia del linter, esto no da error visible: `conform` cae al
`lsp_fallback` y el archivo se guarda formateado por el LSP o sin formatear. El defecto
es más difícil de notar que el ENOENT, pero lleva igual de roto.

**3. En Linux no se instala ningún linter.** `lib/binaries.sh` no baja `black`, `flake8`,
`yamllint` ni `shellcheck`; solo el `Brewfile` de macOS los cubre. En los presets `--vps`
y `--container`, `nvim-lint` falla con ENOENT en Python, YAML, shell y Terraform por
igual.

La salida no es instalar flake8: es colapsar linter y formateador en `ruff`, un único
binario en Rust que sustituye a los dos y no arrastra dependencias de Python.

## Diseño

### Neovim — `config/nvim/lua/plugins/lsp.lua`

Dos sustituciones, sin configuración adicional: `conform.nvim` y `nvim-lint` ya traen
ruff de fábrica (`conform/formatters/ruff_format.lua`, `lint/linters/ruff.lua`).

| Línea | Antes | Después |
|---|---|---|
| 130 | `python = { "black" }` | `python = { "ruff_format" }` |
| 147 | `python = { "flake8" }` | `python = { "ruff" }` |

En el guardado entra **solo `ruff_format`**, el reemplazo directo de black. Se dejan
fuera `ruff_fix` y `ruff_organize_imports` a propósito: reordenar imports y aplicar
autofixes al guardar es un cambio de comportamiento que nadie pidió, y sin configuración
global se aplicaría a cualquier `.py` suelto. Quedan disponibles si más adelante se
quieren.

### macOS — `Brewfile`

`brew "black"` (línea 48) pasa a `brew "ruff"`. Un binario en lugar de dos.

### Linux — `lib/binaries.sh`

Entra en el bloque *Always*, junto a `lazygit`, `delta` y `dust`: el linting no depende
de `--no-cloud` ni de `--no-k8s`, así que no va gated.

```bash
install_if_missing "ruff" \
    "gh_latest_tar astral-sh/ruff '${ARCH_TYPE}-unknown-linux-gnu.tar.gz\"' $LOCAL_BIN '--strip-components=1 --wildcards */ruff'"
```

Tres decisiones deliberadas, las tres verificadas contra el release real:

- **`ARCH_TYPE`, no `GH_ARCH`.** `GH_ARCH` mapea `aarch64` → `arm64`, pero ruff nombra
  sus assets con el triple de Rust, que usa `aarch64-unknown-linux-gnu`. El valor crudo
  de `uname -m` que guarda `ARCH_TYPE` es exactamente el que hace falta. Esta trampa ya
  mordió al repo: ver «Defecto adyacente» más abajo.
- **La comilla de cierre en el patrón.** El release publica `ruff-<triple>.tar.gz` y
  `ruff-<triple>.tar.gz.sha256`, y ambos contienen la subcadena que busca `grep`. Hoy el
  orden de los assets hace que `head -1` acierte, pero es suerte, no garantía: anclar con
  la comilla final del JSON desambigua.
- **`--strip-components=1 --wildcards */ruff`.** El tarball trae directorio contenedor
  (`ruff-x86_64-unknown-linux-gnu/ruff`), igual que `delta` y `dust`.

### Checksums — `lib/binaries.sh:42`

`gh_checksums` busca hoy un archivo consolidado, con el patrón
`checksums?\.txt|sha256sums?|SHA256SUMS`. **Ruff no publica ninguno**: publica un
`.sha256` por asset. Ninguno de esos nombres matchea el patrón, así que ruff se
instalaría con el warning de "no publica checksums" — un mensaje falso, y en contra de la
postura de seguridad que declara la cabecera de `install.sh`.

`gh_checksums` pasa a aceptar un segundo parámetro opcional con el nombre del asset. Si
la búsqueda consolidada no encuentra nada y ese parámetro viene informado, prueba
`<asset>.sha256`. Los archivos de ruff tienen el formato `<sha256>  <nombre>`, que es
justo lo que `verify_sha256` ya espera, así que esa función no se toca.

El parámetro es opcional y la rama consolidada sigue siendo la primera que se intenta:
las nueve llamadas actuales a `gh_latest_tar` / `gh_latest_bin` quedan igual que siempre
y su comportamiento no cambia.

### Defecto adyacente detectado (decisión pendiente)

`delta` (`lib/binaries.sh:120`) y `dust` (`:129`) construyen su patrón con
`${GH_ARCH}-unknown-linux-gnu`. Ambos proyectos publican sus assets ARM como
`aarch64-unknown-linux-gnu`, verificado contra sus releases actuales
(`delta-0.19.2-aarch64-unknown-linux-gnu.tar.gz`,
`dust-v1.2.4-aarch64-unknown-linux-gnu.tar.gz`), pero `GH_ARCH` vale `arm64` en esas
máquinas.

Consecuencia: **en Linux ARM, `delta` y `dust` no se instalan nunca**. `gh_latest_url` no
encuentra asset, devuelve vacío y la instalación se salta sin error visible. En x86_64
`GH_ARCH` y `ARCH_TYPE` coinciden, que es por lo que el defecto no se ha notado.

Es el mismo defecto que este spec evita para ruff, y el arreglo son dos palabras
(`GH_ARCH` → `ARCH_TYPE` en esas dos líneas). Queda anotado aquí para decidirlo
explícitamente: entra en este PR o sale en el suyo, pero no se arregla de tapadillo.

### Configuración de ruff

**Ninguna.** No se añade `config/ruff/ruff.toml` ni symlink. Cada proyecto manda con su
`pyproject.toml` o `ruff.toml`, que es como ya se gestiona Python en este repo (`uv`, un
entorno por proyecto).

Consecuencia, medida sobre ruff 0.16.2 con `ruff check --show-settings --isolated`: el
set por defecto habilita **413 reglas**, entre ellas `I` (isort), `B` (bugbear), `S`
(bandit) y `BLE`. No es más estrecho que el de flake8 (pyflakes + pycodestyle + mccabe),
es bastante más ancho.

Corrige una afirmación previa de este mismo spec, que daba el default como `E4`, `E7`,
`E9`, `F`: eso era cierto en versiones antiguas de ruff, no en la actual. La parte que sí
se mantiene es que **`E501` no se dispara** —verificado con una línea de 105 caracteres—
porque el límite de longitud lo resuelve el formateador.

Efecto secundario que hay que decidir aparte: `I001` (bloque de imports desordenado) **sí**
se reporta, pero como `ruff_organize_imports` no entra en el guardado, el aviso aparece y
no se corrige solo. Ver «Imports: aviso sin arreglo automático».

## Verificación

| Qué | Cómo |
|---|---|
| Lint del shell | `shellcheck -x -S warning install.sh` — lo que exige el CI |
| Sin regresión en macOS | `./install.sh --dry-run` antes y después, diff de la salida |
| Checksum por-asset | Descargar el `.sha256` real de ruff y comprobar que `verify_sha256` lo acepta |
| El defecto original | Abrir un `.py` en nvim y confirmar que no hay ENOENT |

El camino de instalación en Linux no es reproducible desde el Mac de desarrollo. Lo que
sí se valida de forma aislada es la lógica nueva —el fallback de checksums—, que es donde
está el riesgo; la línea de `install_if_missing` sigue el mismo patrón ya probado por
`delta` y `dust`.

## Fuera de alcance

En Linux, `yamllint`, `shellcheck` y `tflint` siguen sin instalarse, así que `nvim-lint`
seguirá dando ENOENT en YAML, shell y Terraform en los presets `--vps` y `--container`.
Es el mismo agujero que este spec cierra para Python, pero mezclarlo aquí convertiría un
cambio acotado en otro mucho mayor: `shellcheck` tiene release de GitHub, pero `yamllint`
es un paquete de Python y necesitaría `uv tool install` o `apt`, que es una decisión de
diseño propia. Va en su propio PR.
