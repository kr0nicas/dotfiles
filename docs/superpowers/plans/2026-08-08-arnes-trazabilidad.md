# Arnés de reglas y trazabilidad — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que un commit mal formado, un secreto o un push directo a `main` no lleguen a existir, y que el "por qué" de cada cambio sea recuperable meses después.

**Architecture:** Hooks bash propios en `.githooks/`, activados por una fase nueva del instalador (`core.hooksPath`). Cada hook define su lógica en funciones y solo la ejecuta cuando git lo invoca, para que la suite de tests pueda hacer `source` del hook y probar las funciones directamente. `CHANGELOG.md` es un archivo generado desde el historial; CI falla si difiere. `main` protegido en GitHub exigiendo PR con 0 aprobaciones.

**Tech Stack:** bash, git, GitHub Actions, `gh` CLI. Sin dependencias nuevas.

**Spec:** `docs/superpowers/specs/2026-08-08-arnes-trazabilidad-design.md`

## Global Constraints

- **bash 3.2 compatible.** `/bin/bash` en macOS es 3.2.57. Prohibido: arrays asociativos (`declare -A`), `mapfile`/`readarray`, `${var,,}`/`${var^^}`, `**` globstar. Usa `case` en vez de arrays asociativos.
- **Degradación obligatoria.** Si falta `shellcheck`, `luajit` o `python3`, el hook avisa y deja pasar. `commit-msg` y el barrido de secretos **nunca** degradan: solo necesitan bash y git.
- **Los hooks van a stderr.** stdout de un hook puede acabar en sitios raros; todo mensaje va a `>&2`.
- **Patrón sourceable.** Todo hook termina con `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then … fi` para que la suite lo pueda sourcear sin dispararlo.
- **`shellcheck -x -S warning`** debe pasar sobre todos los `.sh` y hooks nuevos. Es lo que exige el CI.
- **Idioma:** código y comentarios en español, igual que el resto del repo.
- **Comillas angulares siempre con llaves.** `"«${var}»"`, nunca `"«$var»"`. Bash absorbe el primer byte del `»` (0xC2) dentro del nombre de la variable y con `set -u` aborta con `unbound variable`. Verificado en bash 3.2.57 y 5.3.15: falla en las dos. Aplica a todo mensaje que envuelva un valor en `«»`.
- **Rama de trabajo:** `chore/arnes-trazabilidad`, ya creada, con el spec commiteado.

## File Structure

| Archivo | Responsabilidad | Task |
|---|---|---|
| `.githooks/lib.sh` | Colores, `hook_err/warn/ok/info`, `has()` | 1 |
| `.githooks/scopes.txt` | Lista cerrada de ámbitos válidos | 1 |
| `.githooks/hooks.test.sh` | Suite del arnés | 1–5 |
| `.githooks/commit-msg` | Valida el mensaje | 2 |
| `.githooks/pre-commit` | Lint de lo staged | 3 |
| `.githooks/pre-commit` | Barrido de secretos (mismo archivo) | 4 |
| `.githooks/pre-push` | Guardia de `main` + suite | 5 |
| `lib/repo.sh` | `phase_repo` — activa `core.hooksPath` | 6 |
| `install.sh` | Carga y llama a `phase_repo` | 6 |
| `scripts/changelog.sh` | Genera `CHANGELOG.md` | 7 |
| `CHANGELOG.md` | Generado, no editar | 7 |
| `.github/pull_request_template.md` | Plantilla de PR | 8 |
| `.github/workflows/ci.yml` | Jobs `commit-lint` y `changelog-drift` | 8 |
| `zshrc` | `dots` como función | 9 |
| `CLAUDE.md`, `README.md` | Flujo obligatorio y documentación | 10 |

---

### Task 1: Base del arnés — `lib.sh`, `scopes.txt` y suite

**Files:**
- Create: `.githooks/lib.sh`
- Create: `.githooks/scopes.txt`
- Create: `.githooks/hooks.test.sh`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `hook_err <msg>`, `hook_warn <msg>`, `hook_ok <msg>`, `hook_info <msg>` — escriben a stderr, devuelven 0.
  - `has <cmd>` — 0 si el comando existe.
  - `hook_scopes_file` — imprime la ruta absoluta de `scopes.txt`.
  - `assert_eq <esperado> <obtenido> <nombre>` y `assert_contains <aguja> <pajar> <nombre>` en la suite. Son los dos únicos que usan las tasks 2–5; no añadas más "por si acaso".
  - Variables de la suite: `TESTS_RUN`, `TESTS_FAILED`.

- [ ] **Step 1: Escribir la suite con los primeros tests (fallarán: no hay `lib.sh`)**

Crear `.githooks/hooks.test.sh`:

```bash
#!/usr/bin/env bash
# Tests de los hooks de .githooks/ — sin red, sin dependencias externas.
# Ejecutar: bash .githooks/hooks.test.sh
#
# Los hooks se sourcean, no se ejecutan: cada uno solo dispara su lógica
# cuando git lo invoca (guarda BASH_SOURCE == 0 al final del archivo).

TESTS_RUN=0
TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        printf '  ✓ %s\n' "$name"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  ✗ %s\n' "$name"
        printf '      esperado: «%s»\n' "$expected"
        printf '      obtenido: «%s»\n' "$actual"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" name="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    case "$haystack" in
        *"$needle"*)
            printf '  ✓ %s\n' "$name" ;;
        *)
            TESTS_FAILED=$((TESTS_FAILED + 1))
            printf '  ✗ %s\n' "$name"
            printf '      no se encontró «%s» en la salida\n' "$needle" ;;
    esac
}

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=.githooks/lib.sh
. "$HOOKS_DIR/lib.sh"

printf '\nlib.sh\n'
assert_eq "0" "$(has sh; echo $?)" "has() encuentra un comando que existe"
assert_eq "1" "$(has comando-que-no-existe-jamas; echo $?)" "has() falla con uno que no"
assert_contains "roto" "$(hook_err 'algo roto' 2>&1)" "hook_err escribe a stderr"
assert_contains "✘" "$(hook_err 'x' 2>&1)" "hook_err marca el error con ✘"
assert_contains "⚠" "$(hook_warn 'x' 2>&1)" "hook_warn marca el aviso con ⚠"
assert_eq "" "$(hook_err 'x' 2>/dev/null)" "hook_err no ensucia stdout"

printf '\nscopes.txt\n'
assert_eq "0" "$(grep -qx 'iterm2' "$(hook_scopes_file)"; echo $?)" \
    "el ámbito iterm2 está en la lista"
assert_eq "0" "$(grep -qx 'gcp' "$(hook_scopes_file)"; echo $?)" \
    "el ámbito gcp está en la lista"
assert_eq "1" "$(grep -qx 'gcloud' "$(hook_scopes_file)"; echo $?)" \
    "gcloud NO está: el ámbito del dominio es gcp"

printf '\n%s/%s tests pasaron\n' "$((TESTS_RUN - TESTS_FAILED))" "$TESTS_RUN"
[ "$TESTS_FAILED" -eq 0 ]
```

- [ ] **Step 2: Ejecutar la suite para verificar que falla**

Run: `bash .githooks/hooks.test.sh`
Expected: FAIL — `.githooks/lib.sh: No such file or directory`

- [ ] **Step 3: Escribir `.githooks/lib.sh`**

```bash
#!/usr/bin/env bash
# Helpers compartidos por los hooks. Se carga con `source`; no ejecutar suelto.
#
# Todo va a stderr: el stdout de un hook puede acabar en sitios inesperados
# según cómo lo invoque git.

# Color solo si stderr es un terminal, para no meter escapes en los logs de CI.
if [ -t 2 ]; then
    HOOK_RED=$'\033[0;31m'
    HOOK_YELLOW=$'\033[1;33m'
    HOOK_GREEN=$'\033[0;32m'
    HOOK_DIM=$'\033[2m'
    HOOK_NC=$'\033[0m'
else
    HOOK_RED=''
    HOOK_YELLOW=''
    HOOK_GREEN=''
    HOOK_DIM=''
    HOOK_NC=''
fi

hook_err()  { printf '%s✘ %s%s\n' "$HOOK_RED"    "$*" "$HOOK_NC" >&2; }
hook_warn() { printf '%s⚠ %s%s\n' "$HOOK_YELLOW" "$*" "$HOOK_NC" >&2; }
hook_ok()   { printf '%s✔ %s%s\n' "$HOOK_GREEN"  "$*" "$HOOK_NC" >&2; }
hook_info() { printf '%s  %s%s\n' "$HOOK_DIM"    "$*" "$HOOK_NC" >&2; }

has() { command -v "$1" >/dev/null 2>&1; }

# Ruta de la lista de ámbitos, junto a este archivo.
hook_scopes_file() {
    printf '%s/scopes.txt\n' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
}
```

- [ ] **Step 4: Escribir `.githooks/scopes.txt`**

```
# Ámbitos válidos para el commit. Uno por línea; # inicia comentario.
# Si el tuyo no está, añádelo aquí — cuesta menos que saltarse la regla.
#
# Infraestructura del repo
install
lib
repo
ci
scripts
# Shell
zshrc
zsh
gcp
bin
# Editores
nvim
vim
tmux
# Terminal y prompt
starship
wezterm
iterm2
fonts
# Herramientas
claude
rtk
ssh
direnv
git
brew
# Transversal
docs
```

- [ ] **Step 5: Ejecutar la suite para verificar que pasa**

Run: `bash .githooks/hooks.test.sh`
Expected: `9/9 tests pasaron`, código de salida 0

- [ ] **Step 6: Verificar shellcheck**

Run: `shellcheck -x -S warning .githooks/lib.sh .githooks/hooks.test.sh`
Expected: sin salida, código 0

- [ ] **Step 7: Commit**

```bash
git add .githooks/lib.sh .githooks/scopes.txt .githooks/hooks.test.sh
git commit -m "$(cat <<'EOF'
feat(repo): base del arnés de hooks con su suite de tests

Helpers compartidos, lista cerrada de ámbitos y el arnés de tests, mismo
patrón que config/zsh/gcp.test.zsh: sin dependencias externas, para que la
suite valga igual en un contenedor pelado que en el Mac.

La lista de ámbitos es cerrada a propósito: sin ella acabarían conviviendo
gcp y gcloud como dos ámbitos distintos.
EOF
)"
```

---

### Task 2: `commit-msg` — validar el mensaje

**Files:**
- Create: `.githooks/commit-msg`
- Modify: `.githooks/hooks.test.sh` (añadir bloque de tests antes del resumen final)

**Interfaces:**
- Consumes: `hook_err`, `hook_info`, `hook_scopes_file` de Task 1.
- Produces: `validate_commit_msg <ruta-archivo>` — 0 si válido, 1 si no. Motivo por stderr.

- [ ] **Step 1: Escribir los tests que fallan**

Insertar en `.githooks/hooks.test.sh` justo antes de la línea `printf '\n%s/%s tests pasaron\n'`:

```bash
printf '\ncommit-msg\n'
# shellcheck source=.githooks/commit-msg
. "$HOOKS_DIR/commit-msg"

MSG_TMP="${TMPDIR:-/tmp}/hooks-test-msg-$$"
check_msg() { printf '%s\n' "$1" > "$MSG_TMP"; validate_commit_msg "$MSG_TMP" 2>&1; }
check_rc()  { printf '%s\n' "$1" > "$MSG_TMP"; validate_commit_msg "$MSG_TMP" >/dev/null 2>&1; echo $?; }

assert_eq "0" "$(check_rc 'feat(iterm2): perfil dinámico SRE 2026')" "acepta tipo+ámbito+asunto"
assert_eq "0" "$(check_rc 'docs: documentar la fuente por plataforma')" "acepta sin ámbito"
assert_eq "0" "$(check_rc 'fix(zshrc): quitar alias que rompía du')" "acepta acentos en el asunto"
assert_eq "0" "$(check_rc 'feat(gcp)!: cambiar el nombre del comando')" "acepta el ! de breaking change"

assert_eq "1" "$(check_rc 'Update dots: 2026-07-24')" "rechaza el formato viejo de dots"
assert_eq "1" "$(check_rc 'arreglar el prompt')" "rechaza mensaje sin tipo"
assert_eq "1" "$(check_rc 'feature(iterm2): perfil')" "rechaza tipo desconocido"
assert_eq "1" "$(check_rc 'feat(gcloud): algo')" "rechaza ámbito fuera de la lista"
assert_eq "1" "$(check_rc 'feat(iterm2): Perfil dinámico')" "rechaza asunto en mayúscula"
assert_eq "1" "$(check_rc 'feat(iterm2): perfil dinámico.')" "rechaza punto final"
assert_eq "1" "$(check_rc '')" "rechaza mensaje vacío"
assert_eq "1" "$(check_rc "feat(repo): $(printf 'x%.0s' $(seq 1 80))")" "rechaza asunto de más de 72"

assert_eq "0" "$(check_rc 'fix(zshrc): nota: revisar el README')" "acepta un segundo «: » en el asunto"
assert_eq "0" "$(check_rc 'fix(zshrc): nota: Revisar el README')" \
    "el chequeo de mayúscula mira el asunto, no la línea entera"

assert_eq "0" "$(check_rc "Merge pull request #12 from kr0nicas/feat/iterm2")" "exime los merges"
assert_eq "0" "$(check_rc 'Revert "feat(iterm2): perfil dinámico"')" "exime los reverts"
assert_eq "0" "$(check_rc 'fixup! feat(iterm2): perfil dinámico')" "exime los fixup!"
assert_eq "0" "$(check_rc 'squash! feat(iterm2): perfil dinámico')" "exime los squash!"

assert_contains "gcloud" "$(check_msg 'feat(gcloud): algo')" "el error nombra el ámbito inválido"
assert_contains "scopes.txt" "$(check_msg 'feat(gcloud): algo')" "el error dice dónde añadirlo"
assert_contains "feature" "$(check_msg 'feature(iterm2): x')" "el error nombra el tipo inválido"
assert_contains "72" "$(check_msg "feat(repo): $(printf 'x%.0s' $(seq 1 80))")" "el error cita el límite"

rm -f "$MSG_TMP"
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `bash .githooks/hooks.test.sh`
Expected: FAIL — `.githooks/commit-msg: No such file or directory`

- [ ] **Step 3: Escribir `.githooks/commit-msg`**

```bash
#!/usr/bin/env bash
# Valida el mensaje de commit contra la convención del repo.
# Spec: docs/superpowers/specs/2026-08-08-arnes-trazabilidad-design.md
#
# Este hook NUNCA degrada: solo necesita bash y git.
set -uo pipefail

HOOK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.githooks/lib.sh
. "$HOOK_LIB_DIR/lib.sh"

HOOK_TYPES='feat|fix|docs|refactor|chore|ci|test|perf|build|revert'

hook_ejemplo() {
    hook_info 'Ejemplo válido:'
    hook_info '  feat(iterm2): perfil dinámico SRE 2026'
    hook_info ''
    hook_info "  tipos:  ${HOOK_TYPES//|/, }"
    hook_info "  ámbitos: $(hook_scopes_file)"
}

# validate_commit_msg <archivo> -> 0 válido, 1 inválido
validate_commit_msg() {
    local file="$1" subject tipo scope asunto

    # Primera línea con contenido, ignorando los comentarios que mete git.
    subject="$(grep -v '^#' "$file" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -1)"

    if [ -z "$subject" ]; then
        hook_err 'El mensaje de commit está vacío.'
        hook_ejemplo
        return 1
    fi

    # Exenciones: git genera estos mensajes, no los escribimos nosotros.
    case "$subject" in
        Merge\ *|Revert\ *|fixup!\ *|squash!\ *) return 0 ;;
    esac

    # Estructura general: tipo(ámbito opcional)!: asunto
    if ! printf '%s' "$subject" | grep -qE "^($HOOK_TYPES)(\([a-z0-9.-]+\))?!?: .+"; then
        # ¿Parece conventional pero con el tipo mal?
        if printf '%s' "$subject" | grep -qE '^[A-Za-z]+(\([a-z0-9.-]+\))?!?: '; then
            tipo="$(printf '%s' "$subject" | sed -E 's/^([A-Za-z]+).*/\1/')"
            hook_err "Tipo de commit desconocido: «${tipo}»"
        else
            hook_err 'El mensaje no sigue el formato «tipo(ámbito): asunto».'
        fi
        hook_ejemplo
        return 1
    fi

    # Ámbito, si lo hay, contra la lista cerrada.
    scope="$(printf '%s' "$subject" | sed -nE 's/^[a-z]+\(([a-z0-9.-]+)\).*/\1/p')"
    if [ -n "$scope" ] && ! grep -qx "$scope" "$(hook_scopes_file)"; then
        hook_err "Ámbito desconocido: «${scope}»"
        hook_info "Añádelo a $(hook_scopes_file) si es legítimo."
        hook_info "Válidos: $(grep -v '^#' "$(hook_scopes_file)" | grep -v '^$' | tr '\n' ' ')"
        return 1
    fi

    if [ "${#subject}" -gt 72 ]; then
        hook_err "La primera línea tiene ${#subject} caracteres; el límite son 72."
        return 1
    fi

    # Asunto: minúscula inicial, sin punto final.
    #
    # Se extrae el asunto del prefijo ANTES de mirarlo. Buscar «: [A-Z]» sobre
    # la línea entera da un falso positivo en cuanto el asunto lleva un segundo
    # «: » — «fix(zshrc): nota: Revisar el README» es válido y se rechazaba.
    asunto="$(printf '%s' "$subject" | sed -E "s/^($HOOK_TYPES)(\([a-z0-9.-]+\))?!?: //")"
    if printf '%s' "$asunto" | grep -qE '^[A-ZÁÉÍÓÚÑ]'; then
        hook_err "El asunto empieza en mayúscula: «${asunto}»"
        return 1
    fi

    case "$subject" in
        *.) hook_err 'El asunto termina en punto; quítalo.'; return 1 ;;
    esac

    return 0
}

# Solo actúa cuando git lo invoca; la suite lo sourcea para probar la función.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    validate_commit_msg "$1" || exit 1
fi
```

- [ ] **Step 4: Hacerlo ejecutable y correr la suite**

Run:
```bash
chmod +x .githooks/commit-msg
bash .githooks/hooks.test.sh
```
Expected: `31/31 tests pasaron`, código 0

- [ ] **Step 5: Verificar shellcheck**

Run: `shellcheck -x -S warning .githooks/commit-msg`
Expected: sin salida, código 0

- [ ] **Step 6: Commit**

```bash
git add .githooks/commit-msg .githooks/hooks.test.sh
git commit -m "$(cat <<'EOF'
feat(repo): validar el mensaje de commit en commit-msg

Valida tipo, ámbito contra la lista cerrada, longitud, mayúscula inicial y
punto final. Exime los mensajes que genera git (merge, revert, fixup) para
no bloquear operaciones normales.

Uno de los tests es literalmente el mensaje que producía el alias dots
—«Update dots: 2026-07-24»—, que es el único commit reciente que rompía la
convención.

La lógica vive en validate_commit_msg y el archivo solo la dispara cuando
git lo invoca, para que la suite pueda sourcearlo y probar la función.
EOF
)"
```

---

### Task 3: `pre-commit` — lint de lo staged

**Files:**
- Create: `.githooks/pre-commit`
- Modify: `.githooks/hooks.test.sh`

**Interfaces:**
- Consumes: `hook_err`, `hook_warn`, `hook_info`, `has` de Task 1.
- Produces:
  - `staged_files` — imprime, uno por línea, los archivos añadidos/copiados/modificados/renombrados del índice.
  - `lint_staged <archivo>...` — 0 si todo pasa o degrada; 1 si algo falla de verdad.

- [ ] **Step 1: Escribir los tests que fallan**

Insertar en `.githooks/hooks.test.sh` antes del resumen final:

```bash
printf '\npre-commit — lint\n'
# shellcheck source=.githooks/pre-commit
. "$HOOKS_DIR/pre-commit"

LINT_TMP="${TMPDIR:-/tmp}/hooks-test-lint-$$"
mkdir -p "$LINT_TMP"

printf 'esto no es json\n' > "$LINT_TMP/roto.json"
printf '{"ok": true}\n'    > "$LINT_TMP/bueno.json"

if has python3; then
    assert_eq "1" "$(lint_staged "$LINT_TMP/roto.json" >/dev/null 2>&1; echo $?)" \
        "rechaza un JSON inválido"
    assert_eq "0" "$(lint_staged "$LINT_TMP/bueno.json" >/dev/null 2>&1; echo $?)" \
        "acepta un JSON válido"
    assert_contains "roto.json" "$(lint_staged "$LINT_TMP/roto.json" 2>&1)" \
        "el error nombra el archivo"
else
    printf '  — python3 ausente, tests de JSON omitidos\n'
fi

# Degradación: con la herramienta fuera del PATH debe avisar, no bloquear.
degradado_rc="$(PATH=/nonexistent lint_staged "$LINT_TMP/roto.json" >/dev/null 2>&1; echo $?)"
assert_eq "0" "$degradado_rc" "sin herramientas disponibles deja pasar"
assert_contains "⚠" "$(PATH=/nonexistent lint_staged "$LINT_TMP/roto.json" 2>&1)" \
    "sin herramientas disponibles avisa"

assert_eq "0" "$(lint_staged "$LINT_TMP/no-existe.json" >/dev/null 2>&1; echo $?)" \
    "ignora archivos que ya no existen (borrados en el índice)"

# Enrutado del `case`: con un shellcheck de mentira que siempre falla, un rc=1
# prueba que la ruta llegó a analizarse y un rc=0 que no coincidió con ninguna
# rama. Los patrones son relativos a la raíz del repo, así que se usan rutas
# reales del propio repo en vez de temporales.
STUB_DIR="${TMPDIR:-/tmp}/hooks-test-stub-$$"
STUB_LOG="$STUB_DIR/args.log"
export STUB_LOG
mkdir -p "$STUB_DIR"
# El stub REGISTRA sus argumentos además de fallar. Sin el registro, un test que
# solo mira el código de salida pasa igual con el bug: el código viejo mandaba
# «shellcheck install.sh» pasara lo que pasara, y un stub que siempre sale 1
# habría dado rc=1 en ambas versiones. Lo que discrimina es QUÉ archivo recibe.
printf '#!/bin/sh\nprintf "%%s\\n" "$@" >> "$STUB_LOG"\nexit 1\n' > "$STUB_DIR/shellcheck"
chmod +x "$STUB_DIR/shellcheck"

assert_eq "1" "$(PATH="$STUB_DIR:$PATH" lint_staged '.githooks/commit-msg' >/dev/null 2>&1; echo $?)" \
    "analiza los hooks, que no llevan extensión .sh"
assert_eq "1" "$(PATH="$STUB_DIR:$PATH" lint_staged 'config/bin/cn' >/dev/null 2>&1; echo $?)" \
    "analiza config/bin/cn, que tampoco lleva extensión"
assert_eq "0" "$(PATH="$STUB_DIR:$PATH" lint_staged 'README.md' >/dev/null 2>&1; echo $?)" \
    "no manda a shellcheck lo que no es un script"

: > "$STUB_LOG"
PATH="$STUB_DIR:$PATH" lint_staged 'scripts/github-topics-manager.sh' >/dev/null 2>&1
assert_contains "scripts/github-topics-manager.sh" "$(cat "$STUB_LOG")" \
    "shellcheck recibe el script staged, no install.sh por delegación"

: > "$STUB_LOG"
PATH="$STUB_DIR:$PATH" lint_staged 'lib/symlinks.sh' >/dev/null 2>&1
assert_contains "install.sh" "$(cat "$STUB_LOG")" \
    "un lib/ staged sí delega en install.sh"
assert_contains "-x" "$(cat "$STUB_LOG")" \
    "el análisis de install.sh usa -x para arrastrar lib/"

rm -rf "$STUB_DIR"
rm -rf "$LINT_TMP"
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `bash .githooks/hooks.test.sh`
Expected: FAIL — `.githooks/pre-commit: No such file or directory`

- [ ] **Step 3: Escribir `.githooks/pre-commit` (solo el lint; los secretos van en Task 4)**

```bash
#!/usr/bin/env bash
# Lint de lo que está en el índice, no del repo entero.
# Spec: docs/superpowers/specs/2026-08-08-arnes-trazabilidad-design.md
#
# Degrada a propósito: si falta la herramienta, avisa y deja pasar. Estos
# dotfiles se clonan en cajas sin nada y un hook que exige herramientas
# rompería justo el caso de uso del repo.
set -uo pipefail

HOOK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.githooks/lib.sh
. "$HOOK_LIB_DIR/lib.sh"

# Archivos añadidos/copiados/modificados/renombrados en el índice, separados
# por NUL. Sin -z, un nombre con espacios se partiría en dos y el archivo
# real se saltaría todas las comprobaciones sin decir nada.
staged_files() {
    git diff --cached --name-only --diff-filter=ACMR -z
}

# lint_staged <archivo>... -> 1 si alguna comprobación falla de verdad
lint_staged() {
    local rc=0 f necesita_shellcheck_x=0

    for f in "$@"; do
        [ -f "$f" ] || continue   # borrado o renombrado: nada que mirar

        case "$f" in
            # install.sh arrastra lib/ vía -x. Analizar los lib/ sueltos da
            # SC2034 en cascada por las globales que define install.sh.
            install.sh|lib/*.sh)
                necesita_shellcheck_x=1
                ;;
            # El resto de scripts se analiza individualmente, igual que en
            # ci.yml. Los hooks y config/bin/cn NO llevan extensión .sh, así
            # que van nombrados uno a uno: sin eso no coincidirían con ninguna
            # rama y nunca se analizarían — justo la infraestructura que más
            # falta hace comprobar.
            scripts/*.sh|config/bin/cn|.githooks/*.sh|\
            .githooks/commit-msg|.githooks/pre-commit|.githooks/pre-push)
                if has shellcheck; then
                    shellcheck -S warning "$f" \
                        || { hook_err "shellcheck falló: $f"; rc=1; }
                else
                    hook_warn "shellcheck no está instalado; no se analizó $f"
                fi
                ;;
            zshrc|*.zsh)
                if has zsh; then
                    zsh -n "$f" || { hook_err "zsh -n falló: $f"; rc=1; }
                else
                    hook_warn "zsh no está instalado; no se comprobó $f"
                fi
                ;;
            *.json)
                if has python3; then
                    python3 -m json.tool "$f" >/dev/null \
                        || { hook_err "JSON inválido: $f"; rc=1; }
                else
                    hook_warn "python3 no está instalado; no se comprobó $f"
                fi
                ;;
            *.lua)
                if has luajit; then
                    luajit -bl "$f" /dev/null \
                        || { hook_err "Lua inválido: $f"; rc=1; }
                else
                    hook_warn "luajit no está instalado; no se comprobó $f"
                fi
                ;;
        esac
    done

    # Nota: el prefijo "Nota:" no es decorativo — un comentario que empieza
    # por "# shellcheck" lo interpreta shellcheck como directiva y aborta el
    # análisis del archivo entero con SC1073/SC1072.
    if [ "$necesita_shellcheck_x" -eq 1 ]; then
        if has shellcheck; then
            shellcheck -x -S warning install.sh \
                || { hook_err 'shellcheck falló sobre install.sh'; rc=1; }
        else
            hook_warn 'shellcheck no está instalado; no se analizaron los scripts'
        fi
    fi

    return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    archivos=()
    while IFS= read -r -d '' f; do
        archivos+=("$f")
    done < <(staged_files)
    [ "${#archivos[@]}" -gt 0 ] || exit 0
    lint_staged "${archivos[@]}" || exit 1
fi
```

- [ ] **Step 4: Hacerlo ejecutable y correr la suite**

Run:
```bash
chmod +x .githooks/pre-commit
bash .githooks/hooks.test.sh
```
Expected: `43/43 tests pasaron`, código 0

- [ ] **Step 5: Verificar shellcheck**

Run: `shellcheck -x -S warning .githooks/pre-commit`
Expected: sin salida, código 0

- [ ] **Step 6: Commit**

```bash
git add .githooks/pre-commit .githooks/hooks.test.sh
git commit -m "$(cat <<'EOF'
feat(repo): lint de lo staged en pre-commit

Despacha por extensión sobre el índice, no sobre el repo entero: shellcheck
para los scripts, zsh -n para los .zsh, json.tool para los .json y luajit
para los .lua.

Degrada por diseño cuando falta la herramienta. Un hook que exige shellcheck
rompería el arranque en un VPS pelado, que es justo el caso de uso de este
repo; hay un test que lo fija poniendo PATH a un directorio inexistente.

shellcheck se corre una vez sobre install.sh con -x en vez de sobre cada
lib/ suelto, por el SC2034 en cascada que documenta CLAUDE.md.
EOF
)"
```

---

### Task 4: `pre-commit` — barrido de secretos

**Files:**
- Modify: `.githooks/pre-commit`
- Modify: `.githooks/hooks.test.sh`

**Interfaces:**
- Consumes: `hook_err`, `hook_info` de Task 1; `staged_files` de Task 3.
- Produces: `scan_secrets <archivo>...` — 0 si limpio, 1 si detecta algo. **Nunca degrada.**

- [ ] **Step 1: Escribir los tests que fallan**

Insertar en `.githooks/hooks.test.sh` antes del resumen final:

```bash
printf '\npre-commit — secretos\n'
SEC_TMP="${TMPDIR:-/tmp}/hooks-test-sec-$$"
mkdir -p "$SEC_TMP/.ssh"

printf 'contenido cualquiera\n' > "$SEC_TMP/.ssh/id_rsa"
printf 'contenido cualquiera\n' > "$SEC_TMP/cert.pem"
printf 'AWS_KEY=AKIA%s\n' 'IOSFODNN7EXAMPLE' > "$SEC_TMP/config.env.txt"
printf -- '-----BEGIN %s PRIVATE KEY-----\n' 'OPENSSH' > "$SEC_TMP/inocente.txt"
printf 'export TOKEN=ghp_%s\n' '0123456789abcdefghijklmnopqrstuvwxyz' > "$SEC_TMP/notas.md"
printf '# dotfiles\nnada sensible aquí\n' > "$SEC_TMP/README.md"

assert_eq "1" "$(scan_secrets "$SEC_TMP/.ssh/id_rsa" >/dev/null 2>&1; echo $?)" \
    "bloquea por nombre: id_rsa"
assert_eq "1" "$(scan_secrets "$SEC_TMP/cert.pem" >/dev/null 2>&1; echo $?)" \
    "bloquea por nombre: .pem"
assert_eq "1" "$(scan_secrets "$SEC_TMP/config.env.txt" >/dev/null 2>&1; echo $?)" \
    "bloquea por contenido: clave de AWS"
assert_eq "1" "$(scan_secrets "$SEC_TMP/inocente.txt" >/dev/null 2>&1; echo $?)" \
    "bloquea por contenido: cabecera de clave privada"
assert_eq "1" "$(scan_secrets "$SEC_TMP/notas.md" >/dev/null 2>&1; echo $?)" \
    "bloquea por contenido: token de GitHub"
assert_eq "0" "$(scan_secrets "$SEC_TMP/README.md" >/dev/null 2>&1; echo $?)" \
    "deja pasar un archivo limpio"

assert_contains "id_rsa" "$(scan_secrets "$SEC_TMP/.ssh/id_rsa" 2>&1)" \
    "el error nombra el archivo"
assert_contains "--no-verify" "$(scan_secrets "$SEC_TMP/.ssh/id_rsa" 2>&1)" \
    "el error explica cómo saltárselo a propósito"

# No degrada nunca: sigue bloqueando aunque no haya nada en el PATH.
assert_eq "1" "$(PATH=/nonexistent scan_secrets "$SEC_TMP/.ssh/id_rsa" >/dev/null 2>&1; echo $?)" \
    "el barrido de secretos no degrada"
# El test de arriba solo prueba la rama por NOMBRE, que hace `continue` antes de
# tocar grep. Este prueba la rama por CONTENIDO: con un archivo limpio, un rc=0
# significaría que el barrido se volvió un no-op silencioso.
assert_eq "1" "$(PATH=/nonexistent scan_secrets "$SEC_TMP/README.md" >/dev/null 2>&1; echo $?)" \
    "sin grep falla cerrada en vez de dejar pasar en silencio"

rm -rf "$SEC_TMP"
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `bash .githooks/hooks.test.sh`
Expected: FAIL — `scan_secrets: command not found`

- [ ] **Step 3: Añadir `scan_secrets` a `.githooks/pre-commit`**

Insertar entre la función `lint_staged` y el bloque `if [ "${BASH_SOURCE[0]}" ... ]`:

```bash
# Barrido de secretos. NO degrada: solo usa bash y grep, que siempre están.
# Es la regla de "las llaves nunca van al repo" convertida en algo que no
# depende de que nadie se acuerde.
scan_secrets() {
    local rc=0 f base

    # grep es un ejecutable externo: si no está, la detección por CONTENIDO no
    # puede correr. Esta función tiene prohibido degradar, así que falla
    # CERRADA en vez de dejar pasar. Sin esto un PATH roto la convierte en un
    # no-op silencioso: grep devuelve 127, el `if` lo lee como falso, y el
    # 2>/dev/null se traga hasta el «command not found».
    if ! has grep; then
        hook_err 'grep no disponible: no se puede barrer el contenido en busca de secretos.'
        hook_info 'Arregla el PATH. Si de verdad lo quieres saltar: git commit --no-verify'
        return 1
    fi

    for f in "$@"; do
        [ -f "$f" ] || continue
        # ${f##*/} y no basename: basename es un ejecutable externo y esta
        # función tiene prohibido degradar. Con un PATH roto, basename no se
        # encuentra y el barrido por nombre dejaría de funcionar en silencio.
        base="${f##*/}"

        case "$base" in
            id_rsa|id_dsa|id_ecdsa|id_ed25519|*.pem|*.key|*.p12|*.pfx|.env|.env.*|*.keystore)
                hook_err "Parece material sensible por el nombre: $f"
                rc=1
                continue
                ;;
        esac

        # Contenido: cabecera de clave privada y prefijos de token conocidos.
        if grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$f" 2>/dev/null; then
            hook_err "Clave privada embebida en: $f"
            rc=1
        elif grep -qE '(gh[pousr]_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16})' "$f" 2>/dev/null; then
            hook_err "Token o clave de acceso embebida en: $f"
            rc=1
        fi
    done

    if [ "$rc" -ne 0 ]; then
        hook_info 'Nada de esto va al repo. Si es un falso positivo,'
        hook_info 'sáltatelo a propósito con: git commit --no-verify'
    fi

    return "$rc"
}
```

- [ ] **Step 4: Llamar a `scan_secrets` desde el bloque de ejecución**

Reemplazar el bloque final de `.githooks/pre-commit` por:

```bash
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    archivos=()
    while IFS= read -r -d '' f; do
        archivos+=("$f")
    done < <(staged_files)
    [ "${#archivos[@]}" -gt 0 ] || exit 0

    rc=0
    # Los secretos primero: es el fallo más caro de deshacer.
    scan_secrets "${archivos[@]}" || rc=1
    lint_staged  "${archivos[@]}" || rc=1
    exit "$rc"
fi
```

Añadir además a la suite, en el bloque `pre-commit — secretos`, el test que fija la
propiedad de la que depende todo esto:

```bash
printf 'AWS_KEY=AKIA%s\n' 'IOSFODNN7EXAMPLE' > "$SEC_TMP/nombre con espacios.txt"
assert_eq "1" "$(scan_secrets "$SEC_TMP/nombre con espacios.txt" >/dev/null 2>&1; echo $?)" \
    "detecta secretos en archivos con espacios en el nombre"
```

- [ ] **Step 5: Correr la suite**

Run: `bash .githooks/hooks.test.sh`
Expected: `54/54 tests pasaron`, código 0

- [ ] **Step 6: Verificar shellcheck**

Run: `shellcheck -x -S warning .githooks/pre-commit`
Expected: sin salida, código 0

- [ ] **Step 7: Commit**

```bash
git add .githooks/pre-commit .githooks/hooks.test.sh
git commit -m "$(cat <<'EOF'
feat(repo): barrido de secretos en pre-commit

Bloquea por nombre (id_rsa, *.pem, *.key, .env) y por contenido (cabecera
de clave privada, tokens gh*_ y claves AKIA de AWS).

A diferencia del lint, este barrido no degrada nunca: solo usa bash y grep,
que están en cualquier caja. Un secreto commiteado es el fallo más caro de
deshacer del repo, así que corre antes que el lint.
EOF
)"
```

---

### Task 5: `pre-push` — guardia de `main` y suite

**Files:**
- Create: `.githooks/pre-push`
- Modify: `.githooks/hooks.test.sh`

**Interfaces:**
- Consumes: `hook_err`, `hook_info`, `has` de Task 1.
- Produces: `check_push_ref <ref-local>` — 0 si se puede empujar, 1 si es `main`.

- [ ] **Step 1: Escribir los tests que fallan**

Insertar en `.githooks/hooks.test.sh` antes del resumen final:

```bash
printf '\npre-push\n'
# shellcheck source=.githooks/pre-push
. "$HOOKS_DIR/pre-push"

assert_eq "1" "$(check_push_ref 'refs/heads/main' >/dev/null 2>&1; echo $?)" \
    "bloquea el push a main"
assert_eq "0" "$(check_push_ref 'refs/heads/feat/iterm2-perfil' >/dev/null 2>&1; echo $?)" \
    "deja pasar una rama de feature"
assert_eq "0" "$(check_push_ref 'refs/heads/chore/arnes-trazabilidad' >/dev/null 2>&1; echo $?)" \
    "deja pasar una rama chore"
assert_eq "0" "$(check_push_ref 'refs/tags/v1' >/dev/null 2>&1; echo $?)" \
    "no se mete con los tags"
assert_contains "git switch -c" "$(check_push_ref 'refs/heads/main' 2>&1)" \
    "el error dice cómo crear la rama"
assert_contains "--no-verify" "$(check_push_ref 'refs/heads/main' 2>&1)" \
    "el error explica el bypass"
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `bash .githooks/hooks.test.sh`
Expected: FAIL — `.githooks/pre-push: No such file or directory`

- [ ] **Step 3: Escribir `.githooks/pre-push`**

```bash
#!/usr/bin/env bash
# Guardia de main + suite completa antes de empujar.
# Spec: docs/superpowers/specs/2026-08-08-arnes-trazabilidad-design.md
#
# GitHub también rechaza el push a main por branch protection; esto solo
# hace que el error llegue antes y con instrucciones.
set -uo pipefail

HOOK_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.githooks/lib.sh
. "$HOOK_LIB_DIR/lib.sh"

# check_push_ref <ref-local> -> 1 si la ref es main
check_push_ref() {
    case "$1" in
        refs/heads/main)
            hook_err 'El flujo del repo es rama + PR; main no se empuja directo.'
            hook_info '  git switch -c feat/<ámbito>-<asunto>'
            hook_info '  git push -u origin HEAD && gh pr create --fill'
            hook_info ''
            hook_info 'Emergencia de verdad: git push --no-verify'
            return 1
            ;;
    esac
    return 0
}

# run_suites -> 1 si alguna suite falla
run_suites() {
    local rc=0

    if has zsh && [ -f config/zsh/gcp.test.zsh ]; then
        zsh config/zsh/gcp.test.zsh >/dev/null 2>&1 \
            || { hook_err 'La suite de gcx falla'; rc=1; }
    else
        hook_warn 'zsh no está instalado; no se corrió la suite de gcx'
    fi

    if [ -f .githooks/hooks.test.sh ]; then
        bash .githooks/hooks.test.sh >/dev/null 2>&1 \
            || { hook_err 'La suite de los hooks falla'; rc=1; }
    fi

    return "$rc"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    rc=0
    # git pasa por stdin: <ref-local> <sha-local> <ref-remota> <sha-remoto>
    while read -r local_ref _ _ _; do
        [ -n "$local_ref" ] || continue
        check_push_ref "$local_ref" || rc=1
    done
    [ "$rc" -eq 0 ] || exit 1
    run_suites || exit 1
fi
```

- [ ] **Step 4: Hacerlo ejecutable y correr la suite**

Run:
```bash
chmod +x .githooks/pre-push
bash .githooks/hooks.test.sh
```
Expected: `60/60 tests pasaron`, código 0

- [ ] **Step 5: Verificar shellcheck**

Run: `shellcheck -x -S warning .githooks/pre-push`
Expected: sin salida, código 0

- [ ] **Step 6: Commit**

```bash
git add .githooks/pre-push .githooks/hooks.test.sh
git commit -m "$(cat <<'EOF'
feat(repo): guardia de main y suites en pre-push

Rechaza el push a main con la instrucción de crear la rama, y corre las
suites de gcx y de los hooks antes de dejar salir nada.

GitHub también lo rechazará por branch protection; esto solo hace que el
error llegue antes de la red y explique qué hacer.
EOF
)"
```

---

### Task 6: Activación — `lib/repo.sh` y `install.sh`

**Files:**
- Create: `lib/repo.sh`
- Modify: `install.sh`

**Interfaces:**
- Consumes: `log`, `ok`, `warn`, `section` de `lib/common.sh`; `DOTFILES_DIR`, `DRY_RUN` de `install.sh`.
- Produces: `phase_repo` — configura `core.hooksPath`. Sin valor de retorno usado.

- [ ] **Step 1: Capturar la salida del `--dry-run` actual como oráculo**

Run:
```bash
./install.sh --dry-run --minimal > /tmp/dryrun-antes.txt 2>&1
wc -l /tmp/dryrun-antes.txt
```
Expected: el archivo tiene contenido; guárdalo para comparar en el Step 5.

- [ ] **Step 2: Escribir `lib/repo.sh`**

```bash
#!/usr/bin/env bash
# Fase: configuración del repo (hooks de git).
# Cargado por install.sh. No ejecutar suelto.

phase_repo() {
    # ------------------------------------------------------------------------------
    # 9b. HOOKS DE GIT
    # ------------------------------------------------------------------------------
    section "Configurando hooks del repo"

    if [[ ! -d "$DOTFILES_DIR/.githooks" ]]; then
        warn "No hay .githooks/, omitiendo"
        return
    fi

    # core.hooksPath es config local del clon: no viaja en el repo. Sin esta
    # fase los hooks existen pero no se ejecutan en ninguna máquina nueva.
    if [[ $DRY_RUN -eq 1 ]]; then
        warn "DRY-RUN: git config core.hooksPath .githooks"
        return
    fi

    if ! git -C "$DOTFILES_DIR" config core.hooksPath .githooks 2>/dev/null; then
        warn "No se pudo configurar core.hooksPath (¿no es un repo git?)"
        return
    fi

    # Se comprueba hook por hook en vez de un chmod con `|| true`. Con el
    # `|| true`, un .githooks/ incompleto se anunciaba igual como "Hooks
    # activos": un barrido de secretos ausente se reportaba como presente,
    # que es exactamente la mentira que este arnés existe para evitar.
    local faltan=0 h ruta
    for h in commit-msg pre-commit pre-push; do
        ruta="$DOTFILES_DIR/.githooks/$h"
        if [[ ! -f "$ruta" ]]; then
            warn "Hook ausente: .githooks/$h"
            faltan=1
        elif [[ ! -x "$ruta" ]] && ! chmod +x "$ruta"; then
            warn "No se pudo hacer ejecutable: .githooks/$h"
            faltan=1
        fi
    done

    if [[ $faltan -eq 0 ]]; then
        ok "Hooks activos: commit-msg, pre-commit, pre-push"
    else
        warn "core.hooksPath configurado, pero faltan hooks — revisa los avisos"
    fi
}
```

- [ ] **Step 3: Cargar la fase en `install.sh`**

Localizar la línea que hace `source` de `lib/symlinks.sh` y añadir debajo:

```bash
# shellcheck source=lib/repo.sh
source "$SCRIPT_DIR/lib/repo.sh"
```

- [ ] **Step 4: Llamar a la fase en `install.sh`**

Localizar la llamada a `phase_symlinks` y añadir `phase_repo` inmediatamente después, antes de `phase_verify`.

- [ ] **Step 5: Comprobar equivalencia y la línea nueva**

Run:
```bash
./install.sh --dry-run --minimal > /tmp/dryrun-despues.txt 2>&1
diff /tmp/dryrun-antes.txt /tmp/dryrun-despues.txt
```
Expected: la única diferencia es la sección nueva con `DRY-RUN: git config core.hooksPath .githooks`. Ninguna línea preexistente cambia ni desaparece.

- [ ] **Step 6: Verificar shellcheck y activar los hooks de verdad**

Run:
```bash
shellcheck -x -S warning install.sh
git config core.hooksPath .githooks
git config --get core.hooksPath
```
Expected: shellcheck sin salida; `git config --get` imprime `.githooks`

- [ ] **Step 7: Commit — este es el primero que pasa por los hooks**

```bash
git add lib/repo.sh install.sh
git commit -m "$(cat <<'EOF'
feat(install): activar los hooks del repo con phase_repo

core.hooksPath es configuración local del clon y no viaja en el repo: sin
esta fase los hooks existen pero no se ejecutan en ninguna máquina nueva.

Equivalencia comprobada con --dry-run --minimal antes y después: la única
diferencia es la sección nueva.
EOF
)"
```
Expected: el commit pasa por `commit-msg` y `pre-commit` sin bloquear.

---

### Task 7: `scripts/changelog.sh` y `CHANGELOG.md`

**Files:**
- Create: `scripts/changelog.sh`
- Create: `CHANGELOG.md` (generado)

**Interfaces:**
- Consumes: nada del repo; solo `git`.
- Produces: `scripts/changelog.sh` escribe `CHANGELOG.md`. Con `--check` no escribe y devuelve 1 si el archivo en disco difiere del generado.

- [ ] **Step 1: Escribir `scripts/changelog.sh`**

```bash
#!/usr/bin/env bash
# Genera CHANGELOG.md desde el historial de git.
#
# ARCHIVO GENERADO: no edites CHANGELOG.md a mano, se sobrescribe.
#
# Uso:
#   scripts/changelog.sh            regenera CHANGELOG.md
#   scripts/changelog.sh --check    no escribe; sale 1 si el de disco difiere
#
# La unidad de agrupación es la feature, y se resuelve de dos formas según
# dónde esté (ver el spec): merge commits si ya está en main, main..HEAD si
# sigue en la rama. Ambos caminos tienen que producir el mismo encabezado,
# o el archivo cambiaría solo por mergear.
set -euo pipefail

BASE_BRANCH="${BASE_BRANCH:-main}"
OUT="CHANGELOG.md"

# titulo_de_tipo <tipo> -> nombre de sección. case, no array asociativo:
# /bin/bash en macOS es 3.2 y no los soporta.
titulo_de_tipo() {
    case "$1" in
        feat)     printf 'Features' ;;
        fix)      printf 'Fixes' ;;
        perf)     printf 'Rendimiento' ;;
        refactor) printf 'Refactors' ;;
        docs)     printf 'Documentación' ;;
        test)     printf 'Tests' ;;
        ci|build) printf 'CI' ;;
        chore)    printf 'Mantenimiento' ;;
        revert)   printf 'Reverts' ;;
        *)        printf 'Otros' ;;
    esac
}

# emite_rango <rango> — lista los commits del rango agrupados por tipo.
emite_rango() {
    local rango="$1" tipo linea
    for tipo in feat fix perf refactor docs test ci chore revert; do
        linea="$(git log "$rango" --no-merges --reverse \
                    --format='%h%x09%s' 2>/dev/null \
                 | grep -E "$(printf '^[0-9a-f]+\t%s(\(|!|:)' "$tipo")" || true)"
        [ -n "$linea" ] || continue

        printf '\n### %s\n\n' "$(titulo_de_tipo "$tipo")"
        printf '%s\n' "$linea" | while IFS=$'\t' read -r sha asunto; do
            # «feat(iterm2): perfil» -> «**iterm2**: perfil»
            case "$asunto" in
                *\(*\)*)
                    ambito="$(printf '%s' "$asunto" | sed -E 's/^[a-z]+\(([^)]+)\).*/\1/')"
                    texto="$(printf '%s' "$asunto" | sed -E 's/^[a-z]+\([^)]+\)!?: //')"
                    printf -- '- **%s**: %s (`%s`)\n' "$ambito" "$texto" "$sha"
                    ;;
                *)
                    texto="$(printf '%s' "$asunto" | sed -E 's/^[a-z]+!?: //')"
                    printf -- '- %s (`%s`)\n' "$texto" "$sha"
                    ;;
            esac
        done
    done
}

# La ref base: main local si existe, si no origin/main. En CI el checkout
# del PR no siempre crea la rama local.
base_ref() {
    if git rev-parse --verify --quiet "$BASE_BRANCH" >/dev/null; then
        printf '%s' "$BASE_BRANCH"
    else
        printf 'origin/%s' "$BASE_BRANCH"
    fi
}

# fecha_de <sha> -> YYYY-MM-DD. date -r es BSD, date -d es GNU.
fecha_de() {
    local ts
    ts="$(git log -1 --format='%ct' "$1")"
    date -u -r "$ts" '+%Y-%m-%d' 2>/dev/null || date -u -d "@$ts" '+%Y-%m-%d'
}

# encabezado_de_merge <sha> -> solo el nombre de rama.
#
# El número de PR queda FUERA a propósito: el encabezado tiene que ser
# idéntico antes y después del merge, y antes del merge no hay número que
# leer sin consultar a la API. Si el texto cambiara al mergear, el archivo
# se desincronizaría solo por integrar, y el check de drift sería inútil.
encabezado_de_merge() {
    git log -1 --format='%s' "$1" \
        | sed -E 's|^Merge pull request #[0-9]+ from [^/]+/(.*)$|\1|; s|^Merge branch .(.*).$|\1|'
}

generar() {
    local base sha ts padres fecha asunto rama tip
    base="$(base_ref)"

    printf '# Changelog\n\n'
    printf 'Generado por `scripts/changelog.sh` desde el historial de git.\n'
    printf 'No lo edites a mano: el CI regenera y compara.\n'

    # 1. Feature todavía en la rama, si la hay. Va arriba: es lo más nuevo.
    rama="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$rama" != "$BASE_BRANCH" ] && [ "$rama" != "HEAD" ]; then
        if [ "$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)" -gt 0 ]; then
            # La fecha sale del último commit del rango, no de hoy: si saliera
            # de `date` el archivo cambiaría solo por pasar la medianoche.
            printf '\n## %s · %s\n' "$(fecha_de HEAD)" "$rama"
            emite_rango "$base..HEAD"
        fi
    fi

    # 2. Features ya integradas: main por --first-parent, de la más nueva a la
    #    más vieja.
    git log --first-parent --format='%H %ct %P' "$base" 2>/dev/null \
    | while read -r sha ts padres; do
        case "$padres" in
            *\ *)   # dos o más padres: es un merge, o sea una feature
                # La fecha sale de la punta de la rama (sha^2), no del merge,
                # para que coincida con la que se emitió antes de mergear.
                tip="$(git rev-parse "$sha^2")"
                printf '\n## %s · %s\n' "$(fecha_de "$tip")" "$(encabezado_de_merge "$sha")"
                emite_rango "$sha^1..$sha^2"
                ;;
            *)      # commit suelto en main (historial anterior al arnés)
                fecha="$(fecha_de "$sha")"
                asunto="$(git log -1 --format='%s' "$sha")"
                printf '\n## %s · %s\n\n' "$fecha" "$asunto"
                printf -- '- (`%s`)\n' "$(git log -1 --format='%h' "$sha")"
                ;;
        esac
    done
}

if [ "${1:-}" = "--check" ]; then
    tmp="$(mktemp)"
    trap 'rm -f "$tmp"' EXIT
    generar > "$tmp"
    if ! diff -q "$tmp" "$OUT" >/dev/null 2>&1; then
        printf 'CHANGELOG.md está desactualizado. Corre: scripts/changelog.sh\n' >&2
        diff -u "$OUT" "$tmp" >&2 || true
        exit 1
    fi
    printf 'CHANGELOG.md al día\n'
    exit 0
fi

generar > "$OUT"
printf 'CHANGELOG.md regenerado\n'
```

- [ ] **Step 2: Hacerlo ejecutable y generar el archivo**

Run:
```bash
chmod +x scripts/changelog.sh
./scripts/changelog.sh
head -30 CHANGELOG.md
```
Expected: `CHANGELOG.md regenerado`, y el archivo empieza con `# Changelog` seguido de secciones `## <fecha> · <asunto>`.

- [ ] **Step 3: Verificar que `--check` detecta la desincronización**

Run:
```bash
./scripts/changelog.sh --check && echo "AL DIA"
printf '\nlinea intrusa\n' >> CHANGELOG.md
./scripts/changelog.sh --check; echo "rc=$?"
./scripts/changelog.sh
./scripts/changelog.sh --check && echo "AL DIA OTRA VEZ"
```
Expected: primero `AL DIA`; luego `rc=1` con el diff; tras regenerar, `AL DIA OTRA VEZ`.

- [ ] **Step 4: Verificar que el encabezado sobrevive al merge**

Es la propiedad de la que depende todo el check de drift: si el texto cambia al
mergear, el archivo se desincroniza solo por integrar. Se prueba en un repo de usar y
tirar, sin tocar el real.

Run:
```bash
T="$(mktemp -d)"
git init -q -b main "$T" && cd "$T"
git config user.email t@t && git config user.name t
cp "$OLDPWD/scripts/changelog.sh" .
git commit -q --allow-empty -m 'chore(repo): commit inicial'
git switch -qc feat/prueba-encabezado
git commit -q --allow-empty -m 'feat(iterm2): perfil dinámico'
bash changelog.sh >/dev/null
ANTES="$(grep '^## ' CHANGELOG.md | head -1)"
git switch -q main
git merge -q --no-ff feat/prueba-encabezado -m 'Merge pull request #1 from kr0nicas/feat/prueba-encabezado'
bash changelog.sh >/dev/null
DESPUES="$(grep '^## ' CHANGELOG.md | head -1)"
printf 'antes:   %s\ndespués: %s\n' "$ANTES" "$DESPUES"
[ "$ANTES" = "$DESPUES" ] && echo "ESTABLE" || echo "INESTABLE"
cd "$OLDPWD" && rm -rf "$T"
```
Expected: `ESTABLE`, con ambas líneas iguales (`## <fecha> · feat/prueba-encabezado`). Si sale `INESTABLE`, el `sed` de `encabezado_de_merge` o la fecha de `fecha_de` no coinciden entre los dos caminos — arreglar antes de seguir, porque el job `changelog-drift` depende de esto.

- [ ] **Step 5: Verificar shellcheck**

Run: `shellcheck -S warning scripts/changelog.sh`
Expected: sin salida, código 0

- [ ] **Step 6: Commit**

```bash
git add scripts/changelog.sh CHANGELOG.md
git commit -m "$(cat <<'EOF'
feat(scripts): generar CHANGELOG.md desde el historial

Recorre main por --first-parent para sacar las features y, dentro de cada
merge, sha^1..sha^2 para los commits reales. Esa agrupación es lo que hace
posible el merge --no-ff; con squash no existiría.

--check no escribe y sale 1 si el archivo de disco difiere, que es lo que
usará el CI: sin criterio subjetivo, si falla se corre el script.

Sin arrays asociativos: /bin/bash en macOS es 3.2 y no los soporta.
EOF
)"
```

---

### Task 8: Plantilla de PR y jobs de CI

**Files:**
- Create: `.github/pull_request_template.md`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `.githooks/commit-msg` de Task 2, `.githooks/hooks.test.sh` de Tasks 1–5, `scripts/changelog.sh` de Task 7.
- Produces: jobs `commit-lint` y `changelog-drift`; el job `lint-and-test` pasa a correr también la suite de hooks.

- [ ] **Step 1: Escribir `.github/pull_request_template.md`**

```markdown
## Qué cambia

<!-- Una o dos frases. El diff ya dice el detalle. -->

## Por qué

<!-- El problema real, no la solución. Si hay spec, enlázalo:
     docs/superpowers/specs/YYYY-MM-DD-<tema>-design.md -->

## Cómo se verificó

<!-- Comandos y salida real. "Probado" no es una verificación. -->

```
$ 
```

## Checklist

- [ ] Los mensajes de commit siguen la convención (`.githooks/commit-msg` los validó)
- [ ] `bash .githooks/hooks.test.sh` pasa
- [ ] `zsh config/zsh/gcp.test.zsh` pasa si se tocó `config/zsh/`
- [ ] `shellcheck -x -S warning install.sh` pasa si se tocó `install.sh` o `lib/`
- [ ] `./install.sh --dry-run` comparado antes/después si se tocó el instalador
- [ ] `./scripts/changelog.sh` regenerado como último paso antes del push
- [ ] `CLAUDE.md` actualizado si cambió una convención
```

- [ ] **Step 2: Añadir la suite de hooks al job existente en `.github/workflows/ci.yml`**

Localizar el paso `- name: Suite de tests` y sustituirlo por:

```yaml
      # Las suites corren sin gcloud, sin fzf y sin shellcheck (usan stubs y
      # degradación): es intencional, para que valgan igual en un runner
      # limpio, en un contenedor y en un VPS.
      - name: Suite de tests
        run: |
          zsh config/zsh/gcp.test.zsh
          bash .githooks/hooks.test.sh
```

- [ ] **Step 3: Añadir el job `commit-lint` al final de `ci.yml`**

```yaml
  commit-lint:
    name: Mensajes de commit
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0

      # Misma lógica que en local: se reutiliza el hook, no una copia.
      - name: Validar mensajes del PR
        run: |
          set -e
          base="origin/${{ github.base_ref }}"
          git fetch origin "${{ github.base_ref }}" --depth=0
          rc=0
          for sha in $(git rev-list "$base..HEAD"); do
            git log -1 --format=%B "$sha" > /tmp/msg.txt
            if ! bash .githooks/commit-msg /tmp/msg.txt; then
              echo "  ↑ en $sha"
              rc=1
            fi
          done
          exit $rc
```

- [ ] **Step 4: Añadir el job `changelog-drift` al final de `ci.yml`**

```yaml
  changelog-drift:
    name: CHANGELOG al día
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: Comprobar que CHANGELOG.md está regenerado
        run: ./scripts/changelog.sh --check
```

- [ ] **Step 5: Validar la sintaxis del workflow**

Run:
```bash
python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml')); print('YAML OK')"
```
Expected: `YAML OK`

- [ ] **Step 6: Probar el job de commit-lint en local sobre la rama actual**

Run:
```bash
rc=0
for sha in $(git rev-list main..HEAD); do
  git log -1 --format=%B "$sha" > /tmp/msg.txt
  bash .githooks/commit-msg /tmp/msg.txt || { echo "  ↑ en $sha"; rc=1; }
done
echo "rc=$rc"
```
Expected: `rc=0` — todos los commits de la rama pasan su propia regla.

- [ ] **Step 7: Commit**

```bash
git add .github/pull_request_template.md .github/workflows/ci.yml
git commit -m "$(cat <<'EOF'
ci: validar mensajes y CHANGELOG en CI, y plantilla de PR

commit-lint recorre origin/main..HEAD y pasa cada mensaje por el mismo
.githooks/commit-msg que corre en local, para que no haya dos lógicas que
puedan divergir. Necesita fetch-depth 0.

changelog-drift regenera y compara: si falla, se corre el script.

La plantilla pide salida real de comandos en «cómo se verificó»; "probado"
no es una verificación.
EOF
)"
```

---

### Task 9: `dots` como función

**Files:**
- Modify: `zshrc`

**Interfaces:**
- Consumes: `.githooks/commit-msg` de Task 2 (indirectamente, vía `git commit`).
- Produces: función `dots <mensaje>` en el entorno interactivo.

- [ ] **Step 1: Localizar el alias actual**

Run: `grep -n "alias dots" zshrc`
Expected: una línea con el alias `git add . && commit … && push`.

- [ ] **Step 2: Sustituir el alias por la función**

Reemplazar esa línea por:

```zsh
# dots — guardar cambios de los dotfiles bajo el flujo de rama + PR.
# Antes era un alias que hacía `git add . && commit "Update dots: $(date)" && push`
# sobre main: bajo las reglas del repo falla en tres sitios a la vez (rama
# prohibida, mensaje inválido y add indiscriminado).
dots() {
    local msg="$1" rama
    if [[ -z "$msg" ]]; then
        print -u2 "  ✗ uso: dots '<tipo>(<ámbito>): <asunto>'"
        print -u2 "     ej: dots 'fix(zshrc): quitar alias que rompía du'"
        return 2
    fi

    ( cd "$HOME/dotfiles" || return 1

      if [[ "$(git branch --show-current)" == "main" ]]; then
          # feat(iterm2): perfil dinámico  ->  feat/iterm2-perfil-dinamico
          rama=$(print -r -- "$msg" \
              | sed -E 's/^([a-z]+)\(([a-z0-9.-]+)\): /\1\/\2-/; s/^([a-z]+): /\1\//' \
              | tr '[:upper:]' '[:lower:]' \
              | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
              | sed -E 's/[^a-z0-9\/-]+/-/g; s/-+/-/g; s/-$//' \
              | cut -c1-60)
          git switch -c "$rama" || return 1
      fi

      git add -A && git commit -m "$msg" || return 1
      git push -u origin HEAD || return 1

      if command -v gh > /dev/null && [[ -z "$(gh pr view --json number 2>/dev/null)" ]]; then
          gh pr create --fill
      fi
    )
}
```

- [ ] **Step 3: Comprobar la sintaxis**

Run: `zsh -n zshrc && echo "ZSH OK"`
Expected: `ZSH OK`

- [ ] **Step 4: Probar la derivación del nombre de rama sin tocar git**

Run:
```bash
zsh -c '
msg="feat(iterm2): perfil dinámico SRE 2026"
print -r -- "$msg" \
  | sed -E "s/^([a-z]+)\(([a-z0-9.-]+)\): /\1\/\2-/; s/^([a-z]+): /\1\//" \
  | tr "[:upper:]" "[:lower:]" \
  | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
  | sed -E "s/[^a-z0-9\/-]+/-/g; s/-+/-/g; s/-\$//" \
  | cut -c1-60'
```
Expected: `feat/iterm2-perfil-dinamico-sre-2026`

- [ ] **Step 5: Probar el error sin argumento**

Run: `zsh -c 'source zshrc >/dev/null 2>&1; dots; echo "rc=$?"' 2>&1 | tail -3`
Expected: el mensaje de uso y `rc=2`

- [ ] **Step 6: Commit**

```bash
git add zshrc
git commit -m "$(cat <<'EOF'
refactor(zshrc): dots pasa de alias a función con rama y PR

El alias hacía `git add . && commit "Update dots: $(date)" && push` sobre
main, que bajo las reglas nuevas falla en tres sitios a la vez: rama
prohibida, mensaje inválido y add indiscriminado. Era además la fuente del
único commit reciente que rompía la convención (c2f35e7).

Ahora exige el mensaje en formato convencional, deriva la rama de él cuando
estás en main, y abre el PR si hay gh. Sin fechas autogeneradas.
EOF
)"
```

---

### Task 10: Documentación y regla de comportamiento

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: nada ejecutable.

- [ ] **Step 1: Añadir la sección de flujo a `CLAUDE.md`**

Insertar después de la sección "Installation & common commands":

```markdown
## Flujo de trabajo (obligatorio)

Nunca se commitea directo a `main`: está protegido en GitHub y `pre-push` lo rechaza antes.

1. **Rama antes de tocar código.** `git switch -c feat/<ámbito>-<asunto>`. Si ya empezaste en `main`, mueve el trabajo a una rama antes de commitear.
2. **Commit al cerrar cada unidad de trabajo**, sin esperar a que te lo pidan. El cuerpo explica el *porqué*; el diff ya dice el qué.
3. **PR al terminar.** `gh pr create --fill`, y `gh pr merge --merge --delete-branch` (`--no-ff`, nunca squash: el CHANGELOG se genera de esa estructura).
4. **Regenerar el CHANGELOG** con `./scripts/changelog.sh` como último paso antes del push final. El CI falla si difiere.

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
```

- [ ] **Step 2: Actualizar la referencia obsoleta a `dots` en `CLAUDE.md`**

Localizar el bloque:

```
Update dotfiles:
​```bash
dots    # alias: git add . && commit with date && push from ~/dotfiles
​```
```

Sustituir la línea del alias por:

```
dots 'fix(zshrc): quitar alias que rompía du'   # rama + commit + push + PR
```

- [ ] **Step 3: Añadir la sección al `README.md`**

Insertar antes de "🛡️ Notas de seguridad", y añadir la entrada correspondiente al índice:

```markdown
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
```

- [ ] **Step 4: Regenerar el CHANGELOG y correr todo**

Run:
```bash
./scripts/changelog.sh
bash .githooks/hooks.test.sh
zsh config/zsh/gcp.test.zsh
shellcheck -x -S warning install.sh
zsh -n zshrc
```
Expected: todo pasa, código 0 en cada uno.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md README.md CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs(repo): documentar el arnés y el flujo obligatorio

La sección de flujo en CLAUDE.md es la pieza que hace que la regla se
cumpla en sesiones futuras: sin ella el resto es andamiaje que un agente
puede ignorar, con ella es lo primero que lee.

Actualiza también la referencia a dots, que seguía describiendo el alias
viejo con fecha autogenerada.
EOF
)"
```

---

### Task 11: Cierre — PR, protección de `main` y limpieza

**Files:** ninguno. Operaciones sobre git y GitHub.

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: `main` protegido; ramas obsoletas resueltas.

- [ ] **Step 1: Empujar las dos ramas y abrir los PRs**

Run:
```bash
git push -u origin chore/arnes-trazabilidad
gh pr create --fill --title "chore(repo): arnés de reglas y trazabilidad"
git push -u origin feat/terminal-iterm2-fuentes
gh pr create --head feat/terminal-iterm2-fuentes --fill \
  --title "feat(terminal): perfil de iTerm2 y fuente Nerd por plataforma"
```
Expected: dos PRs abiertos. `pre-push` corre las suites antes de cada push.

- [ ] **Step 2: Esperar CI y mergear el PR del arnés**

Run:
```bash
gh pr checks --watch
gh pr merge --merge --delete-branch
```
Expected: checks en verde; merge con commit de merge (no squash).

- [ ] **Step 3: Inspeccionar las 4 ramas remotas obsoletas antes de tocarlas**

Run:
```bash
for b in feat/backup-safe-link-and-docs feat/modular-install \
         fix/audit-critical-high fix/audit-low-medium; do
  printf '\n=== %s\n' "$b"
  git log --oneline "origin/main..origin/$b"
  git diff --stat "origin/main...origin/$b" | tail -5
done
```
Expected: el contenido del único commit de cada rama. **No borrar nada aún**: reportar al usuario qué hay en cada una y esperar su decisión.

- [ ] **Step 4: Limpiar los worktrees huérfanos**

Run:
```bash
git worktree list
git worktree prune
git worktree list
```
Expected: desaparecen los que ya no tienen directorio. Los que sigan, confirmar con el usuario antes de `git worktree remove`.

- [ ] **Step 5: Resolver el PR de dependabot**

Run:
```bash
gh pr view 5
gh pr checks 5
```
Expected: mostrar el estado al usuario y preguntar si mergear la subida de `actions/checkout` 5→7.

- [ ] **Step 6: Aplicar la protección de `main` — REQUIERE CONFIRMACIÓN EXPLÍCITA**

Es una acción sobre un repo público. Pedir confirmación antes de ejecutar.

Run:
```bash
gh api -X PUT repos/kr0nicas/dotfiles/branches/main/protection \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Lint y tests", "Mensajes de commit", "CHANGELOG al día"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": false
}
JSON
```

- [ ] **Step 7: Verificar que la protección funciona de verdad**

Run:
```bash
gh api repos/kr0nicas/dotfiles/branches/main/protection \
  --jq '{checks: .required_status_checks.contexts, admins: .enforce_admins.enabled, reviews: .required_pull_request_reviews.required_approving_review_count}'
git switch main && git pull
git commit --allow-empty -m 'chore(repo): probar la protección de main'
git push origin main; echo "rc=$?"
```
Expected: el `gh api` muestra los tres contextos, `admins: false`, `reviews: 0`. El `push` es **rechazado** con `protected branch hook declined` y `rc` distinto de 0. Deshacer con `git reset --hard HEAD~1`.

---

## Self-Review

**Cobertura del spec:**

| Sección del spec | Task |
|---|---|
| 1. Regla del commit | 2 |
| 2. `.githooks/` tres puertas | 1, 2, 3, 4, 5 |
| 3. Activación (`core.hooksPath`) | 6 |
| 4. Flujo de trabajo + `dots` | 9, 10 |
| 5. CHANGELOG generado | 7 |
| 6. Plantilla de PR y CI | 8 |
| 7. Protección de `main` | 11 |
| 8. Regla de comportamiento | 10 |
| 9. Tests del arnés | 1–5 |
| Plan de migración | 11 |

Sin huecos.

**Consistencia de nombres verificada:** `hook_err`/`hook_warn`/`hook_ok`/`hook_info`, `has`, `hook_scopes_file` (Task 1) se usan con esos mismos nombres en Tasks 2–5. `staged_files` y `lint_staged` (Task 3) los consume el bloque de ejecución de Task 4. `validate_commit_msg` (Task 2) lo invoca el job `commit-lint` de Task 8 vía `bash .githooks/commit-msg`. `check_push_ref` y `run_suites` (Task 5) solo se usan dentro de su archivo.

**Cuentas de tests acumuladas:** Task 1 → 9, Task 2 → 31, Task 3 → 43, Task 4 → 54, Task 5 → 60. Si al implementar no cuadran, es que un `assert` se quedó fuera; revisar antes de seguir.

**Corrección aplicada durante esta revisión.** El primer borrador de `scripts/changelog.sh` solo recorría `main`, así que no implementaba el camino "todavía en la rama" que exige la sección 5 del spec: en un PR el archivo habría salido vacío de la feature en curso y el check de drift habría pasado en falso. Además el encabezado incluía el número de PR, que no existe antes de mergear, de modo que el texto cambiaba al integrar y el archivo se desincronizaba solo. Resuelto así:

- El encabezado es **solo el nombre de rama**, idéntico por los dos caminos.
- La fecha sale del **último commit del rango** (`HEAD` en la rama, `sha^2` tras el merge), nunca de `date`, que haría cambiar el archivo al pasar la medianoche.
- La ref base se resuelve a `main` o `origin/main` según exista, porque el checkout de un PR en CI no siempre crea la rama local.
- Task 7 Step 4 prueba la propiedad en un repo temporal y falla ruidosamente si se rompe.

Consecuencia sobre el spec: el ejemplo de la sección 5 muestra `## 2026-08-08 · #13 Perfil de iTerm2…`. El número de PR no puede ir ahí. El spec se corrige junto con este plan.

**Riesgo que queda abierto:** el job `changelog-drift` corre también sobre el PR del propio arnés, donde `scripts/changelog.sh` todavía no existe en `main`. Task 11 Step 2 lo absorbe porque el job se incorpora en el mismo PR que el script; si el runner fallara por ese orden, mergear con el check en rojo una única vez es aceptable y queda en el audit log.
