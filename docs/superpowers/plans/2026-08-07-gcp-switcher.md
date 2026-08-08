# `gcx` Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sustituir los cuatro aliases de GCP desincronizados por un comando `gcx` con pickers fzf de cuenta y proyecto, cuyos mensajes se leen siempre de gcloud.

**Architecture:** Un archivo zsh autocontenido (`config/zsh/gcp.zsh`) sourceado desde `zshrc`. Helpers puros (rutas de caché, filtrado) separados de la capa que llama a `gcloud` y `fzf`, para poder testear los primeros sin red ni autenticación. La caché de proyectos vive en `~/.cache/gcp`, con clave por cuenta.

**Tech Stack:** zsh, gcloud CLI, fzf, `column`/`awk` (BSD y GNU).

Spec: `docs/superpowers/specs/2026-08-07-gcp-switcher-design.md`

## Global Constraints

- Ningún mensaje de estado puede hardcodear cuenta o proyecto: siempre se leen de `gcloud`. Esta es la causa raíz del defecto original.
- `gcloud config configurations list` requiere las rutas completas `properties.core.account` y `properties.core.project`. Las formas cortas `account` / `project` devuelven **cadena vacía** sin error.
- Verificación de sintaxis: `zsh -n <archivo>`. **No usar `shellcheck`** — no soporta zsh, aunque esté instalado.
- El picker de configuraciones lista **todas** las configs sin filtrar, incluida `default` (vacía). Decisión explícita del usuario.
- Los proyectos `^sys-` (Apps Script) se ocultan del picker de proyectos.
- El repo nunca versiona credenciales ni configuraciones de gcloud. Solo emails en documentación.
- Idioma de mensajes y comentarios: español, coherente con el resto de `zshrc`.
- La caché es por **cuenta**, no por configuración: `~/.cache/gcp/projects-<cuenta-sanitizada>.list`.

---

### Task 1: Esqueleto, helpers puros y arnés de tests

Crea el archivo, los dos helpers sin dependencias externas, y el arnés de tests que usarán todas las tareas siguientes.

**Files:**
- Create: `config/zsh/gcp.zsh`
- Create: `config/zsh/gcp.test.zsh`

**Interfaces:**
- Consumes: nada.
- Produces:
  - `GCP_CACHE_DIR` — variable, por defecto `$HOME/.cache/gcp`, sobreescribible por el entorno (los tests dependen de esto).
  - `_gcp_cache_path <account>` → imprime la ruta absoluta del archivo de caché de esa cuenta.
  - `_gcp_filter_projects` → filtro stdin→stdout que elimina líneas que empiezan por `sys-`.
  - En el test: `assert_eq <esperado> <obtenido> <nombre>` y `assert_contains <aguja> <pajar> <nombre>`.

- [ ] **Step 1: Escribe el test que falla**

Crea `config/zsh/gcp.test.zsh`:

```zsh
#!/usr/bin/env zsh
# Tests de config/zsh/gcp.zsh — solo helpers puros (sin red, sin gcloud).
# Ejecutar: zsh config/zsh/gcp.test.zsh

typeset -g TESTS_RUN=0 TESTS_FAILED=0

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    (( TESTS_RUN++ ))
    if [[ "$expected" == "$actual" ]]; then
        print "  ✓ $name"
    else
        (( TESTS_FAILED++ ))
        print "  ✗ $name"
        print "      esperado: «$expected»"
        print "      obtenido: «$actual»"
    fi
}

assert_contains() {
    local needle="$1" haystack="$2" name="$3"
    (( TESTS_RUN++ ))
    if [[ "$haystack" == *"$needle"* ]]; then
        print "  ✓ $name"
    else
        (( TESTS_FAILED++ ))
        print "  ✗ $name"
        print "      no se encontró «$needle» en la salida"
    fi
}

# Caché aislada para los tests
export GCP_CACHE_DIR="${TMPDIR:-/tmp}/gcp-test-cache-$$"
source "${0:A:h}/gcp.zsh"

print "\n_gcp_cache_path"
assert_eq "$GCP_CACHE_DIR/projects-jorge.ochoa_itproject41.com.list" \
          "$(_gcp_cache_path 'jorge.ochoa@itproject41.com')" \
          "sanitiza la @ del email"
assert_eq "$GCP_CACHE_DIR/projects-ochoa.j_gmail.com.list" \
          "$(_gcp_cache_path 'ochoa.j@gmail.com')" \
          "cuentas distintas dan archivos distintos"
assert_eq "$GCP_CACHE_DIR/projects-raro__.list" \
          "$(_gcp_cache_path 'raro/ ')" \
          "sanitiza caracteres de ruta"

print "\n_gcp_filter_projects"
projects=$'kelova-app\tkelova-app\nsys-01877150826042451366448604\tsys\nitproject-n8n-customers\titproject-n8n-customers'
filtered="$(print -r -- "$projects" | _gcp_filter_projects)"
assert_contains "kelova-app" "$filtered" "conserva proyectos normales"
assert_contains "itproject-n8n-customers" "$filtered" "conserva proyectos con guiones"
assert_eq "2" "$(print -r -- "$filtered" | grep -c .)" "elimina exactamente los sys-*"
assert_eq "" "$(print -r -- "$filtered" | grep '^sys-')" "no queda ningún sys-*"

rm -rf "$GCP_CACHE_DIR"
print "\n$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN tests pasaron"
(( TESTS_FAILED == 0 ))
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: FAIL — `no such file or directory: .../gcp.zsh`

- [ ] **Step 3: Escribe la implementación mínima**

Crea `config/zsh/gcp.zsh`:

```zsh
# ------------------------------------------------------------------------------
# gcx — switcher de cuentas y proyectos de Google Cloud
# ------------------------------------------------------------------------------
# Cargado desde zshrc. Requiere gcloud; los pickers requieren fzf.
#
# Principio de diseño: ningún mensaje hardcodea cuenta ni proyecto. Todo se lee
# de gcloud, para que la salida no pueda desincronizarse de la realidad.

: ${GCP_CACHE_DIR:="$HOME/.cache/gcp"}

# --- helpers puros (sin red, sin gcloud) --------------------------------------

# Ruta del archivo de caché de una cuenta. Sanitiza cualquier carácter que no
# sea seguro en un nombre de archivo (la @ del email, sobre todo).
_gcp_cache_path() {
    local account="$1"
    print -r -- "$GCP_CACHE_DIR/projects-${account//[^a-zA-Z0-9._-]/_}.list"
}

# Filtra de stdin los proyectos sys-* que Apps Script autogenera. Son ~15 de los
# 38 visibles y hacen inservible el picker.
_gcp_filter_projects() {
    grep -v '^sys-'
}
```

- [ ] **Step 4: Ejecuta el test para verificar que pasa**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: PASS — `7/7 tests pasaron`

- [ ] **Step 5: Verifica la sintaxis**

Run: `cd ~/dotfiles && zsh -n config/zsh/gcp.zsh && echo OK`
Expected: `OK`

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add config/zsh/gcp.zsh config/zsh/gcp.test.zsh
git commit -m "feat(gcp): helpers de caché y filtrado con tests"
```

---

### Task 2: Lectura de estado y activación de configuraciones

Los comandos que no necesitan fzf: consultar estado y activar una config por nombre.

**Files:**
- Modify: `config/zsh/gcp.zsh` (añadir al final)
- Modify: `config/zsh/gcp.test.zsh` (añadir antes del bloque `rm -rf`)

**Interfaces:**
- Consumes: `_gcp_cache_path`, `_gcp_filter_projects` de la Task 1.
- Produces:
  - `_gcp_active_account` → imprime el email de la cuenta activa, o vacío.
  - `_gcp_active_project` → imprime el projectId activo, o vacío.
  - `_gcp_active_config` → imprime el nombre de la configuración activa, o vacío.
  - `_gcp_config_exists <name>` → código de salida 0 si existe, 1 si no.
  - `_gcp_who` → imprime tres líneas: config, cuenta, proyecto.
  - `_gcp_use <name>` → activa la config y llama a `_gcp_who`. Devuelve 2 sin argumento, 1 si la config no existe.

- [ ] **Step 1: Escribe el test que falla**

En `config/zsh/gcp.test.zsh`, inserta justo antes de la línea `rm -rf "$GCP_CACHE_DIR"`:

```zsh
print "\n_gcp_use (validación de argumentos)"
out="$(_gcp_use 2>&1)"
assert_eq "2" "$?" "sin argumento devuelve código 2"
assert_contains "uso: gcx use" "$out" "sin argumento imprime el uso"

out="$(_gcp_use 'no-existe-jamas-xyz' 2>&1)"
assert_eq "1" "$?" "config inexistente devuelve código 1"
assert_contains "no existe la configuración" "$out" "config inexistente lo dice"
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: FAIL — `command not found: _gcp_use`

- [ ] **Step 3: Escribe la implementación mínima**

Añade al final de `config/zsh/gcp.zsh`:

```zsh
# --- lectura de estado --------------------------------------------------------
# OJO: en `configurations list` hay que usar las rutas completas
# properties.core.account y properties.core.project. Las formas cortas
# (account, project) devuelven cadena vacía sin dar error.

_gcp_active_account() {
    gcloud config list --format='value(core.account)' 2>/dev/null
}

_gcp_active_project() {
    gcloud config list --format='value(core.project)' 2>/dev/null
}

_gcp_active_config() {
    gcloud config configurations list \
        --filter='is_active=true' --format='value(name)' 2>/dev/null
}

_gcp_config_exists() {
    gcloud config configurations list --format='value(name)' 2>/dev/null \
        | grep -qx -- "$1"
}

_gcp_who() {
    local cfg acct proj
    cfg="$(_gcp_active_config)"
    acct="$(_gcp_active_account)"
    proj="$(_gcp_active_project)"
    print -r -- "  config    ${cfg:-—}"
    print -r -- "  cuenta    ${acct:-—}"
    print -r -- "  proyecto  ${proj:-—}"
}

# --- activación ---------------------------------------------------------------

_gcp_use() {
    local name="$1"
    if [[ -z "$name" ]]; then
        print -r -- "uso: gcx use <config>" >&2
        return 2
    fi
    if ! _gcp_config_exists "$name"; then
        print -r -- "  ✗ no existe la configuración «$name»" >&2
        print -r -- "    disponibles: $(gcloud config configurations list \
            --format='value(name)' 2>/dev/null | paste -sd' ' -)" >&2
        return 1
    fi
    gcloud config configurations activate "$name" >/dev/null 2>&1 || return 1
    _gcp_who
}
```

- [ ] **Step 4: Ejecuta el test para verificar que pasa**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: PASS — `11/11 tests pasaron`

- [ ] **Step 5: Verifica a mano contra gcloud real**

```bash
cd ~/dotfiles && source config/zsh/gcp.zsh
_gcp_who
gcloud config list --format='value(core.account,core.project)'
```
Expected: la cuenta y el proyecto de `_gcp_who` coinciden exactamente con la salida de `gcloud`.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add config/zsh/gcp.zsh config/zsh/gcp.test.zsh
git commit -m "feat(gcp): lectura de estado y activación de configuraciones"
```

---

### Task 3: Caché y picker de proyectos

**Files:**
- Modify: `config/zsh/gcp.zsh` (añadir al final)
- Modify: `config/zsh/gcp.test.zsh` (añadir antes del bloque `rm -rf`)

**Interfaces:**
- Consumes: `_gcp_cache_path`, `_gcp_filter_projects`, `_gcp_active_account`, `_gcp_who`.
- Produces:
  - `_gcp_refresh_cache <account>` → reescribe la caché desde la API. Si la API falla pero hay caché previa, avisa y devuelve 0. Si falla y no hay caché, devuelve 1.
  - `_gcp_pick_project [-r|--refresh]` → picker fzf; al elegir hace `gcloud config set project` y llama a `_gcp_who`.

- [ ] **Step 1: Escribe el test que falla**

En `config/zsh/gcp.test.zsh`, inserta antes de `rm -rf "$GCP_CACHE_DIR"`:

```zsh
print "\n_gcp_refresh_cache (degradación sin red)"
# Simulamos un gcloud que siempre falla, para probar el camino de error.
gcloud() { return 1 }
cache_file="$(_gcp_cache_path 'test@example.com')"

mkdir -p "$GCP_CACHE_DIR"
rm -f "$cache_file"
out="$(_gcp_refresh_cache 'test@example.com' 2>&1)"
assert_eq "1" "$?" "sin caché previa y sin red devuelve 1"
assert_contains "gcloud auth login" "$out" "sugiere autenticarse"

print -r -- $'viejo-proyecto\tviejo' > "$cache_file"
out="$(_gcp_refresh_cache 'test@example.com' 2>&1)"
assert_eq "0" "$?" "con caché previa y sin red devuelve 0"
assert_contains "caché anterior" "$out" "avisa de que usa caché vieja"
assert_contains "viejo-proyecto" "$(<"$cache_file")" "no destruye la caché previa"
unfunction gcloud
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: FAIL — `command not found: _gcp_refresh_cache`

- [ ] **Step 3: Escribe la implementación mínima**

Añade al final de `config/zsh/gcp.zsh`:

```zsh
# --- caché de proyectos -------------------------------------------------------
# Clave por cuenta, no por configuración: dos configs de la misma cuenta
# comparten lista, y cambiar de cuenta nunca mezcla resultados.

_gcp_refresh_cache() {
    local account="$1" cache tmp n
    cache="$(_gcp_cache_path "$account")"
    tmp="${cache}.tmp"
    mkdir -p "$GCP_CACHE_DIR"

    if gcloud projects list --format='value(projectId,name)' >"$tmp" 2>/dev/null; then
        _gcp_filter_projects <"$tmp" >"$cache"
        rm -f "$tmp"
        n="$(grep -c . <"$cache")"
        print -r -- "  ↻ $n proyectos cacheados para $account"
        return 0
    fi

    rm -f "$tmp"
    if [[ -s "$cache" ]]; then
        print -r -- "  ⚠ no se pudo consultar GCP; usando la caché anterior de $account" >&2
        return 0
    fi
    print -r -- "  ✗ no se pudo consultar GCP y no hay caché para $account" >&2
    print -r -- "    ¿autenticado? prueba: gcloud auth login" >&2
    return 1
}

# --- picker de proyectos ------------------------------------------------------

_gcp_pick_project() {
    local refresh=0 account cache sel proj
    [[ "$1" == "-r" || "$1" == "--refresh" ]] && refresh=1

    command -v fzf >/dev/null 2>&1 || {
        print -r -- "  ✗ gcx requiere fzf" >&2; return 1
    }

    account="$(_gcp_active_account)"
    if [[ -z "$account" ]]; then
        print -r -- "  ✗ no hay cuenta activa. prueba: gcloud auth login" >&2
        return 1
    fi

    cache="$(_gcp_cache_path "$account")"
    if (( refresh )) || [[ ! -s "$cache" ]]; then
        (( refresh )) || print -r -- "  primera carga para $account, consultando GCP..."
        _gcp_refresh_cache "$account" || return 1
    fi

    sel="$(column -t -s $'\t' <"$cache" \
        | fzf --prompt='gcx project > ' --height=40% --reverse)" || return 0
    [[ -z "$sel" ]] && return 0

    proj="${sel%% *}"
    gcloud config set project "$proj" >/dev/null 2>&1 || {
        print -r -- "  ✗ no se pudo fijar el proyecto $proj" >&2; return 1
    }
    _gcp_who
}
```

- [ ] **Step 4: Ejecuta el test para verificar que pasa**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: PASS — `16/16 tests pasaron`

- [ ] **Step 5: Verifica el picker a mano**

```bash
cd ~/dotfiles && source config/zsh/gcp.zsh
_gcp_pick_project -r
```
Expected: reporta el número de proyectos cacheados, abre fzf, **no aparece ningún `sys-`**. Elige uno y comprueba que `_gcp_who` refleja el cambio. Después, `_gcp_pick_project` debe abrir de forma instantánea. Pulsar Esc no debe cambiar nada.

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add config/zsh/gcp.zsh config/zsh/gcp.test.zsh
git commit -m "feat(gcp): caché por cuenta y picker de proyectos"
```

---

### Task 4: Picker de configuraciones y dispatcher `gcx`

**Files:**
- Modify: `config/zsh/gcp.zsh` (añadir al final)
- Modify: `zshrc:71` (añadir el `source` tras el bloque de lazy loading)

**Interfaces:**
- Consumes: `_gcp_use`, `_gcp_who`, `_gcp_pick_project`.
- Produces:
  - `_gcp_config_table` → imprime la tabla de configuraciones ya formateada y alineada (marca `●`/`○`, nombre, cuenta, proyecto). La usan **tanto** `_gcp_pick_config` como `_gcp_help` (Task 5); no dupliques el bloque `awk` en ninguna de las dos.
  - `_gcp_pick_config` → picker fzf de configuraciones; marca la activa con `●`.
  - `gcx [subcomando]` → punto de entrada. Sin argumentos abre `_gcp_pick_config`.

**Referencia adelantada esperada:** el dispatcher llama a `_gcp_help`, que no existe hasta la Task 5. Al terminar esta tarea, `gcx -h` fallará con `command not found: _gcp_help`. Es correcto — no intentes arreglarlo aquí. Los tests de esta tarea solo cubren el camino del subcomando inválido.

- [ ] **Step 1: Escribe el test que falla**

En `config/zsh/gcp.test.zsh`, antes de `rm -rf "$GCP_CACHE_DIR"`:

```zsh
print "\ngcp (dispatcher)"
out="$(gcx subcomando-invalido 2>&1)"
assert_eq "2" "$?" "subcomando desconocido devuelve código 2"
assert_contains "subcomando desconocido" "$out" "nombra el subcomando inválido"
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: FAIL — `command not found: gcx`

- [ ] **Step 3: Escribe la implementación mínima**

Añade al final de `config/zsh/gcp.zsh`:

```zsh
# --- picker de configuraciones ------------------------------------------------
# Lista TODAS las configs sin filtrar, incluida la 'default' vacía que gcloud
# exige: el picker refleja lo que gcloud tiene, sin excepciones ocultas.

# Tabla de configuraciones, alineada y con la activa marcada. Fuente única para
# el picker y para `gcx -h`.
_gcp_config_table() {
    gcloud config configurations list \
        --format='value(name,is_active,properties.core.account,properties.core.project)' 2>/dev/null \
    | awk -F'\t' '{
          printf "%s\t%s\t%s\t%s\n",
              ($2 == "True" ? "●" : "○"),
              $1,
              ($3 == "" ? "—" : $3),
              ($4 == "" ? "—" : $4)
      }' \
    | column -t -s $'\t'
}

_gcp_pick_config() {
    local sel

    command -v fzf >/dev/null 2>&1 || {
        print -r -- "  ✗ gcx requiere fzf" >&2; return 1
    }

    sel="$(_gcp_config_table \
        | fzf --prompt='gcx config > ' --height=40% --reverse)" || return 0
    [[ -z "$sel" ]] && return 0

    # campo 1 = marca ●/○, campo 2 = nombre de la config
    _gcp_use "$(print -r -- "$sel" | awk '{print $2}')"
}

# --- punto de entrada ---------------------------------------------------------

gcx() {
    case "$1" in
        '')             _gcp_pick_config ;;
        p|project)      shift; _gcp_pick_project "$@" ;;
        use)            shift; _gcp_use "$@" ;;
        who)            _gcp_who ;;
        -h|--help|help) _gcp_help ;;
        *)
            print -r -- "  ✗ subcomando desconocido: $1" >&2
            print -r -- "    prueba: gcx -h" >&2
            return 2
            ;;
    esac
}
```

- [ ] **Step 4: Ejecuta el test para verificar que pasa**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: PASS — `18/18 tests pasaron`

- [ ] **Step 5: Conecta el archivo a zshrc**

En `zshrc`, justo después de la línea 71 (`bq() { gcloud "$@"; bq "$@" }`), añade:

```zsh

# GCP: switcher de cuentas y proyectos (comando `gcx`, ver `gcx -h`)
[ -f "$HOME/dotfiles/config/zsh/gcp.zsh" ] && source "$HOME/dotfiles/config/zsh/gcp.zsh"
```

- [ ] **Step 6: Verifica el picker en un shell real**

```bash
zsh -n ~/dotfiles/zshrc && echo "sintaxis OK"
exec zsh
gcx
```
Expected: fzf muestra las 5 configuraciones (`default`, `facturaya`, `itproject`, `kelova`, `personal`), con `●` en la activa y **las columnas de cuenta y proyecto rellenas** (si salen vacías, se está usando la forma corta del formato en vez de `properties.core.*`). Elegir una imprime config/cuenta/proyecto correctos.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles
git add config/zsh/gcp.zsh config/zsh/gcp.test.zsh zshrc
git commit -m "feat(gcp): picker de configuraciones y dispatcher gcx"
```

---

### Task 5: Ayuda de referencia, aliases y cheatsheet

`gcx -h` es la hoja de referencia permanente: comandos, aliases con su cuenta, semántica de la caché, y las configuraciones leídas en vivo.

**Files:**
- Modify: `config/zsh/gcp.zsh` (añadir `_gcp_help`)
- Modify: `config/zsh/gcp.test.zsh`
- Modify: `zshrc:267-271` (reemplazar el bloque de aliases GCP)
- Modify: `CHEAT_CODES.md:328` (sección GCP)

**Interfaces:**
- Consumes: `_gcp_config_table` de la Task 4 — **reutilízala**, no vuelvas a escribir el bloque `awk`.
- Produces: `_gcp_help` → imprime la referencia completa.

- [ ] **Step 1: Escribe el test que falla**

En `config/zsh/gcp.test.zsh`, antes de `rm -rf "$GCP_CACHE_DIR"`:

```zsh
print "\n_gcp_help"
help_out="$(gcx -h 2>&1)"
assert_contains "gcx p"    "$help_out" "documenta el picker de proyectos"
assert_contains "gcx p -r" "$help_out" "documenta el refresco de caché"
assert_contains "gcx use"  "$help_out" "documenta gcx use"
assert_contains "gcx who"  "$help_out" "documenta gcx who"
assert_contains "gcpers"   "$help_out" "documenta los aliases"
assert_contains "gckel"    "$help_out" "documenta el alias nuevo"
assert_contains "$GCP_CACHE_DIR" "$help_out" "muestra la ruta real de la caché"
assert_contains "sys-"     "$help_out" "explica el filtrado de sys-*"
```

- [ ] **Step 2: Ejecuta el test para verificar que falla**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: FAIL — `command not found: _gcp_help`

- [ ] **Step 3: Escribe la implementación mínima**

Añade a `config/zsh/gcp.zsh`, **antes** de la definición de `gcx()`:

```zsh
# --- ayuda --------------------------------------------------------------------

_gcp_help() {
    print -r -- ""
    print -r -- "  gcx — switcher de cuentas y proyectos de Google Cloud"
    print -r -- ""
    print -r -- "  USO"
    print -r -- "    gcx                Picker de configuraciones (cuenta + proyecto)"
    print -r -- "    gcx p              Picker de proyectos de la cuenta activa (caché, instantáneo)"
    print -r -- "    gcx p -r           Refresca la caché desde la API (~5s) y abre el picker"
    print -r -- "    gcx use <config>   Activa una configuración por nombre, sin picker"
    print -r -- "    gcx who            Config, cuenta y proyecto activos"
    print -r -- "    gcx -h             Esta referencia"
    print -r -- ""
    print -r -- "  ALIASES"
    print -r -- "    gcpers   gcx use personal      ochoa.j@gmail.com"
    print -r -- "    gcit     gcx use itproject     jorge.ochoa@itproject41.com"
    print -r -- "    gcfact   gcx use facturaya     administrator@facturayasv.com"
    print -r -- "    gckel    gcx use kelova        jorge.ochoa@itproject41.com"
    print -r -- "    gcwho    gcx who"
    print -r -- ""
    print -r -- "  CÓMO FUNCIONA"
    print -r -- "    · El proyecto de cada config es solo dónde aterrizas: 'gcx p' salta a"
    print -r -- "      cualquier otro proyecto sin cambiar de cuenta."
    print -r -- "    · La caché es por cuenta, no por config:"
    print -r -- "        $GCP_CACHE_DIR/projects-<cuenta>.list"
    print -r -- "      Cambiar de config nunca mezcla listas."
    print -r -- "    · Los proyectos sys-* (autogenerados por Apps Script) se ocultan."
    print -r -- "    · Los mensajes se leen de gcloud, nunca están hardcodeados: no pueden"
    print -r -- "      desincronizarse de la realidad."
    print -r -- "    · Cancelar el fzf con Esc no cambia nada."
    print -r -- ""
    print -r -- "  CONFIGURACIONES ACTUALES"
    _gcp_config_table | sed 's/^/    /'
    print -r -- ""
}
```

- [ ] **Step 4: Ejecuta el test para verificar que pasa**

Run: `cd ~/dotfiles && zsh config/zsh/gcp.test.zsh`
Expected: PASS — `26/26 tests pasaron`

- [ ] **Step 5: Reemplaza los aliases en zshrc**

En `zshrc`, sustituye el bloque de las líneas 267-271 por:

```zsh
# GCP: cambiar entre configuraciones/cuentas (ver `gcx -h`)
# Delegan en `gcx use`, que valida e imprime el estado leído de gcloud.
# Nunca vuelvas a poner la cuenta en un echo: es lo que hizo que mintieran.
alias gcpers='gcx use personal'
alias gcit='gcx use itproject'
alias gcfact='gcx use facturaya'
alias gckel='gcx use kelova'
alias gcwho='gcx who'
```

- [ ] **Step 6: Actualiza el cheatsheet**

En `CHEAT_CODES.md`, en la sección `### GCP` (línea 328), añade **antes** de la tabla existente:

```markdown
**Switcher `gcx`** — cambiar de cuenta y proyecto (referencia completa: `gcx -h`)

| Comando | Acción |
|---|---|
| `gcx` | Picker de configuraciones (cuenta + proyecto) |
| `gcx p` | Picker de proyectos de la cuenta activa (caché, instantáneo) |
| `gcx p -r` | Refresca la caché desde la API y abre el picker |
| `gcx use <config>` | Activa una configuración por nombre |
| `gcx who` / `gcwho` | Config, cuenta y proyecto activos |
| `gcpers` `gcit` `gcfact` `gckel` | Atajos a cada configuración |

Configuraciones: `personal` (ochoa.j@gmail.com), `itproject` (jorge.ochoa@itproject41.com →
itproject-n8n-customers), `facturaya` (administrator@facturayasv.com → factura-electronica-sv),
`kelova` (jorge.ochoa@itproject41.com → kelova-app).

La caché vive en `~/.cache/gcp/projects-<cuenta>.list` y oculta los proyectos `sys-*`.
```

- [ ] **Step 7: Verifica en un shell real**

```bash
exec zsh
gcx -h
gcwho
```
Expected: `gcx -h` muestra las cuatro secciones y las 5 configuraciones al final. `gcwho` imprime config/cuenta/proyecto.

- [ ] **Step 8: Commit**

```bash
cd ~/dotfiles
git add config/zsh/gcp.zsh config/zsh/gcp.test.zsh zshrc CHEAT_CODES.md
git commit -m "feat(gcp): referencia en gcx -h, aliases corregidos y cheatsheet"
```

---

### Task 6: Arreglar el lazy-load de gsutil/bq y borrar el `.zshrc` duplicado

**Files:**
- Modify: `zshrc:63-71`
- Delete: `.zshrc`

**Interfaces:**
- Consumes: nada.
- Produces: `_gcloud_lazy_load` → carga `path.zsh.inc` y `completion.zsh.inc` una sola vez.

- [ ] **Step 1: Reproduce el defecto**

```bash
zsh -c 'source ~/dotfiles/zshrc; gsutil ls gs://no-existe-xyz 2>&1 | head -5'
```
Expected: aparece un error de `gcloud` sobre un grupo/comando `ls` inválido **antes** de la salida real de `gsutil`. Ese es el defecto: `gsutil() { gcloud "$@"; ... }` ejecuta `gcloud` con los argumentos de `gsutil`.

- [ ] **Step 2: Escribe la corrección**

Sustituye las líneas 63-71 de `zshrc` por:

```zsh
# gcloud/gsutil/bq: el SDK tarda en cargar, así que diferimos path y completions
# hasta la primera invocación. El helper NO recibe los argumentos del comando:
# pasárselos hacía que `gsutil ls ...` ejecutase antes `gcloud ls ...` y
# escupiera un error en cada primer uso.
_gcloud_lazy_load() {
    unset -f gcloud gsutil bq
    local GCLOUD_PATH="$HOME/google-cloud-sdk"
    [ -f "$GCLOUD_PATH/path.zsh.inc" ] && . "$GCLOUD_PATH/path.zsh.inc"
    [ -f "$GCLOUD_PATH/completion.zsh.inc" ] && . "$GCLOUD_PATH/completion.zsh.inc"
    return 0   # el último [ -f ] puede ser falso; no propagar ese estado
}
gcloud() { _gcloud_lazy_load; gcloud "$@" }
gsutil() { _gcloud_lazy_load; gsutil "$@" }
bq()     { _gcloud_lazy_load; bq "$@" }
```

- [ ] **Step 3: Verifica que el defecto desapareció**

```bash
zsh -n ~/dotfiles/zshrc && echo "sintaxis OK"
zsh -c 'source ~/dotfiles/zshrc; gsutil ls gs://no-existe-xyz 2>&1 | head -5'
```
Expected: ya **no** aparece el error de `gcloud` sobre un comando inválido. Solo la salida propia de `gsutil`.

- [ ] **Step 4: Verifica que gcloud sigue funcionando**

```bash
zsh -c 'source ~/dotfiles/zshrc; gcloud config list --format="value(core.account)"'
```
Expected: imprime la cuenta activa, sin errores.

- [ ] **Step 5: Borra el `.zshrc` duplicado**

Confirma primero que nadie lo usa:

```bash
cd ~/dotfiles
readlink ~/.zshrc                    # debe apuntar a ~/dotfiles/zshrc, no a .zshrc
grep -rn '"\$DOTFILES_DIR/\.zshrc"' install.sh || echo "install.sh no lo referencia"
git rm .zshrc
```

- [ ] **Step 6: Commit**

```bash
cd ~/dotfiles
git add zshrc
git commit -m "fix(zshrc): lazy-load de gsutil/bq sin ejecutar gcloud con argumentos ajenos

Eliminado también el .zshrc duplicado: install.sh solo enlaza zshrc."
```

---

### Task 7: Reparar las configuraciones de gcloud

Operación única contra gcloud. No toca el repo — no se versionan configuraciones ni credenciales.

**Files:** ninguno (estado local de gcloud).

**Interfaces:**
- Consumes: el comando `gcx` de las tareas anteriores para verificar.
- Produces: las cinco configuraciones alineadas con la tabla del spec.

- [ ] **Step 1: Captura el estado actual por si hay que revertir**

```bash
gcloud config configurations list \
  --format='value(name,is_active,properties.core.account,properties.core.project)' \
  | tee ~/gcloud-configs-backup-2026-08-07.txt
```
Expected: se guardan las 5 líneas actuales.

- [ ] **Step 2: Corrige `personal`**

```bash
gcloud config configurations activate personal
gcloud config set account ochoa.j@gmail.com
gcloud config unset project
```
Expected: `personal` queda con la cuenta de gmail y sin proyecto.

- [ ] **Step 3: Corrige `itproject`**

```bash
gcloud config configurations activate itproject
gcloud config set account jorge.ochoa@itproject41.com
gcloud config set project itproject-n8n-customers
```
Expected: `itproject` deja de ser un duplicado de `facturaya`.

- [ ] **Step 4: Confirma `facturaya` (ya era correcta)**

```bash
gcloud config configurations activate facturaya
gcloud config set account administrator@facturayasv.com
gcloud config set project factura-electronica-sv
```
Expected: sin cambios efectivos; se aplica por idempotencia.

- [ ] **Step 5: Corrige `kelova`**

```bash
gcloud config configurations activate kelova
gcloud config set account jorge.ochoa@itproject41.com
gcloud config set project kelova-app
```
Expected: deja de combinar la cuenta de ITProject con un proyecto de Facturaya.

- [ ] **Step 6: Verifica el resultado completo**

```bash
exec zsh
gcx -h
```
Expected: la sección CONFIGURACIONES ACTUALES coincide exactamente con:

| Config | Cuenta | Proyecto |
|---|---|---|
| `personal` | ochoa.j@gmail.com | — |
| `itproject` | jorge.ochoa@itproject41.com | itproject-n8n-customers |
| `facturaya` | administrator@facturayasv.com | factura-electronica-sv |
| `kelova` | jorge.ochoa@itproject41.com | kelova-app |
| `default` | — | — |

- [ ] **Step 7: Verifica que la caché es por cuenta**

```bash
gcit && gcx p -r    # cachea para jorge.ochoa@itproject41.com
gcfact && gcx p -r  # cachea para administrator@facturayasv.com
ls -1 ~/.cache/gcp/
```
Expected: dos archivos distintos, uno por cuenta. Ningún proyecto `sys-` en ninguno.

- [ ] **Step 8: Ejecuta la suite completa una última vez**

```bash
cd ~/dotfiles
zsh config/zsh/gcp.test.zsh
zsh -n zshrc && zsh -n config/zsh/gcp.zsh && echo "sintaxis OK"
```
Expected: `26/26 tests pasaron` y `sintaxis OK`.

- [ ] **Step 9: Limpia el backup**

```bash
rm ~/gcloud-configs-backup-2026-08-07.txt
```

---

## Verificación final (spec § Verificación)

- [ ] `gcx` lista las cinco configuraciones y marca la activa con `●`.
- [ ] `gcx use <cada config>` imprime cuenta y proyecto que coinciden con `gcloud config list`.
- [ ] `gcx p` abre instantáneo tras la primera carga y no muestra ningún `sys-*`.
- [ ] `gcx p -r` refresca y reporta el número de proyectos cacheados.
- [ ] Cada cuenta tiene su propio archivo de caché; cambiar de config no altera la lista de otra.
- [ ] `gsutil ls` y `bq ls` no imprimen errores de `gcloud` en la primera invocación de la sesión.
- [ ] `gcx -h` documenta todos los comandos y aliases, y lista las configs en vivo.
- [ ] `zsh -n zshrc` y `zsh -n config/zsh/gcp.zsh` pasan.
