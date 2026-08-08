# `gcp` — switcher de cuentas y proyectos de Google Cloud

Fecha: 2026-08-07
Estado: diseño aprobado

## Problema

El flujo actual para moverse entre cuentas y proyectos de GCP vive en cuatro aliases
(`zshrc:268-271`) y está roto en tres frentes.

**Los aliases mienten.** Cada uno imprime un `echo` hardcodeado que ya no coincide con
la configuración que activa:

| Alias | Mensaje que imprime | Cuenta real de la config | Proyecto real |
|---|---|---|---|
| `gcpers` | personal · ochoa.j@gmail.com | `jorge.ochoa@itproject41.com` | *(ninguno)* |
| `gcit` | ITProject · jorge.ochoa@itproject41.com | `administrator@facturayasv.com` | factura-electronica-sv |
| `gcfact` | Facturaya · administrator@facturayasv.com | correcto | factura-electronica-sv |

Además `itproject` y `facturaya` son configuraciones idénticas, la configuración activa
`kelova` no tiene alias, y `ochoa.j@gmail.com` está autenticada pero ninguna config la usa.

**No hay forma de cambiar de proyecto.** Los aliases solo activan configuraciones. La
cuenta `jorge.ochoa@itproject41.com` ve 38 proyectos y tres de las cuatro configs apuntan
al mismo `factura-electronica-sv` — un proyecto que esa cuenta ni siquiera puede listar,
porque pertenece a la cuenta de Facturaya.

**Ruido de fondo.** 15 de los 38 proyectos son `sys-*` autogenerados por Apps Script.
Cualquier listado sin filtrar es inservible.

## Solución

Un comando `gcp` con subcomandos, en un archivo propio, que lee siempre su estado de
gcloud en vez de repetir constantes.

### Ubicación

```
config/zsh/gcp.zsh
```

Se carga desde `zshrc` con una línea (`source ~/dotfiles/config/zsh/gcp.zsh`), igual que
ya se hace con `~/.zshrc.local`. No necesita symlink en `install.sh`.

`zshrc` ya tiene 333 líneas; las ~150 de `gcp` viven aparte para mantener ambos archivos
legibles y para poder probar el switcher de forma aislada.

### Interfaz

```
gcp                  Picker fzf de configuraciones → activa la elegida
gcp p                Picker fzf de proyectos de la cuenta activa (caché, instantáneo)
gcp p -r             Refresca la caché desde la API (~5s) y abre el picker
gcp use <config>     Activa una configuración por nombre, sin picker
gcp who              Config, cuenta y proyecto activos
gcp -h               Hoja de referencia completa
```

Sin argumentos hace lo más frecuente. `gcp p` es lo segundo más frecuente. Nada más.

### Comportamiento

**Picker de configuraciones.** Lee en vivo con `gcloud config configurations list` —
operación local, sin red. Marca la activa. Lista **todas** las configuraciones sin filtrar,
incluida `default` (vacía): el picker refleja lo que gcloud tiene, sin excepciones ocultas.
Al elegir, hace `activate` e imprime el estado
resultante **leído de gcloud**. Este es el punto central del diseño: ningún mensaje se
hardcodea, así que ninguno puede volver a desincronizarse.

**Picker de proyectos.** Caché en `~/.cache/gcp/projects-<cuenta>.list`, una línea por
proyecto (`id` y nombre). La clave de caché es la cuenta, no la configuración, así que
cada identidad mantiene su propia lista y cambiar de config nunca mezcla resultados.
Filtra `^sys-`. Si no existe caché, la construye en la primera invocación y lo avisa. Al
elegir, ejecuta `gcloud config set project`, que persiste en la configuración activa.

**`gcp use`.** Valida que la configuración exista antes de activarla. Si no existe, falla
con un mensaje explícito en vez de dejar el shell en un estado ambiguo.

**`gcp -h`.** Hoja de referencia: comandos, aliases con la cuenta de cada uno, ubicación y
semántica de la caché, y al final la lista de configuraciones leída en vivo. Sirve como
recordatorio permanente sin poder quedar obsoleta.

### Aliases

Se conservan los nombres cortos, pero delegando en `gcp use` en vez de repetir literales:

```zsh
alias gcpers='gcp use personal'
alias gcit='gcp use itproject'
alias gcfact='gcp use facturaya'
alias gckel='gcp use kelova'      # nuevo: hoy no existe
alias gcwho='gcp who'
```

Si una configuración se renombra, el alias falla de forma ruidosa en lugar de imprimir
información falsa.

### Reparación de configuraciones

Operación única, ejecutada contra gcloud y documentada en `CHEAT_CODES.md`. No se versiona
en el repo (ni configs ni credenciales).

| Config | Cuenta | Proyecto |
|---|---|---|
| `personal` | ochoa.j@gmail.com | *(sin proyecto)* |
| `itproject` | jorge.ochoa@itproject41.com | itproject-n8n-customers |
| `facturaya` | administrator@facturayasv.com | factura-electronica-sv |
| `kelova` | jorge.ochoa@itproject41.com | kelova-app |
| `default` | *(vacía — gcloud la exige)* | |

Esto elimina el duplicado `itproject`/`facturaya` y deshace el cruce de `kelova`, que
combinaba la cuenta de ITProject con un proyecto de Facturaya.

El proyecto de cada config es solo el punto de aterrizaje; `gcp p` permite saltar a
cualquier otro proyecto de esa cuenta sin cambiar de identidad.

### Errores

| Situación | Comportamiento |
|---|---|
| Falta `fzf` | Mensaje claro y salida con código distinto de cero |
| Cuenta activa sin autenticar | Sugiere `gcloud auth login` |
| `projects list` falla | Conserva la caché anterior y avisa; no deja al usuario sin lista |
| fzf cancelado (Esc) | No cambia nada, salida limpia |
| `gcp use` con config inexistente | Error explícito, no activa nada |

## Defectos corregidos de paso

**`zshrc:70-71`.** El lazy-load de `gsutil` y `bq` ejecuta `gcloud` con los argumentos del
otro comando:

```zsh
gsutil() { gcloud "$@"; gsutil "$@" }
```

`gsutil ls gs://bucket` lanza primero `gcloud ls gs://bucket`, que imprime un error, antes
de correr el comando real. Funciona por accidente y ensucia la salida en cada primer uso.

**`.zshrc` duplicado.** El repo versiona `.zshrc` y `zshrc`. `install.sh:768` solo enlaza
`zshrc`; `.zshrc` es una copia vieja (aún con p10k instant prompt) que nadie usa. Se
elimina con `git rm`.

## Fuera de alcance

- Colores de terminal por proyecto o entorno, al estilo del wrapper `ssh()` de `zshrc:158-222`.
- Versionado de las configuraciones de gcloud en el repo con un `gcp sync`.

Ambas se pueden añadir después sin rehacer nada de lo anterior.

## Verificación

- `gcp` lista las cinco configuraciones y marca la activa correctamente.
- `gcp use <cada config>` activa e imprime cuenta y proyecto que coinciden con
  `gcloud config list`.
- `gcp p` abre instantáneo tras la primera carga y no muestra ningún proyecto `sys-*`.
- `gcp p -r` refresca y reporta el número de proyectos cacheados.
- La caché de cada cuenta es un archivo distinto; cambiar de config no altera la lista de otra.
- `gsutil ls` y `bq ls` no imprimen errores de `gcloud` en la primera invocación de la sesión.
- `zsh -n config/zsh/gcp.zsh` y `zsh -n zshrc` pasan sin advertencias. (No se usa
  `shellcheck`: está instalado en la máquina pero no soporta zsh.)
