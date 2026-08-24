# gcx: cambio de ADC por cuenta y aviso en `gcx who`

Fecha: 2026-08-24
Estado: aprobado

## Problema

`gcloud config configurations activate` (y por tanto `gcx use`) cambia la
config, la cuenta y el proyecto del CLI, pero **no toca las Application
Default Credentials**: `~/.config/gcloud/application_default_credentials.json`
es un archivo aparte que solo reescribe `gcloud auth application-default
login`. Resultado: OpenTofu, los SDKs y cualquier aplicación que use ADC
siguen atacando la cuenta y el `quota_project_id` viejos por mucho que `gcx`
diga otra cosa. En esta máquina las ADC llevaban clavadas
`administrator@facturayasv.com` / `factura-electronica-sv` mientras se
trabajaba en otras configs, y nada avisaba.

## Diseño

Dos piezas: un almacén de ADC por cuenta que `gcx use` intercambia, y una
línea de estado con aviso en `gcx who`. Todo en `config/zsh/gcp.zsh`.

### Almacén de ADC por cuenta

- Ruta: `${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/adc/<cuenta-sanitizada>.json`,
  permisos 600 (y 700 el directorio). La sanitización es la misma de
  `_gcp_cache_path` (todo lo que no sea `[a-zA-Z0-9._-]` → `_`).
- **No** va en `GCP_CACHE_DIR`: son credenciales, no caché regenerable, y
  `~/.cache` es candidato a limpieza.

### Subcomando nuevo: `gcx adc`

1. Corre `gcloud auth application-default login` (interactivo, abre
   navegador — es la única forma en que Google emite el refresh token; se
   hace una vez por cuenta y vida del token).
2. Si el login termina bien, copia el
   `application_default_credentials.json` resultante al almacén, keyed por
   la **cuenta activa** en ese momento.
3. Si hay proyecto activo, parchea `quota_project_id` con `jq` en la copia
   viva (no en la guardada: la guardada es de la cuenta; el quota project es
   de la config).

### `gcx use <config>` (ampliación)

Tras activar la config, con la cuenta y el proyecto ya leídos de gcloud:

- Si existe ADC guardada para esa cuenta → la copia sobre
  `application_default_credentials.json` (temporal + `mv`, como la caché de
  proyectos) y, si hay proyecto activo, parchea `quota_project_id` con `jq`.
- Si no existe → aviso: `no hay ADC guardadas para <cuenta>; emítelas una
  vez con: gcx adc`.
- El parcheo con `jq` es local e instantáneo; no se usa
  `gcloud auth application-default set-quota-project`, que hace una llamada
  de red y valida permisos en cada cambio.

### `gcx who` (ampliación)

Cuarta línea fija `adc <quota_project|—>` y aviso solo en desajuste:

```
  config    kelova
  cuenta    jorge.ochoa@itproject41.com
  proyecto  kelova-app
  adc       factura-electronica-sv  ⚠ no coincide
    remedio: gcx use kelova   (o gcx adc si esta cuenta aún no tiene ADC guardadas)
```

El remedio se construye con la config activa real — nada hardcodeado.

### Helpers

| Helper | Tipo | Qué hace |
|---|---|---|
| `_gcp_adc_dir` | puro | Ruta del almacén, respetando `CLOUDSDK_CONFIG` |
| `_gcp_adc_store_path <cuenta>` | puro | Ruta de la ADC guardada de una cuenta |
| `_gcp_adc_live_path` | puro | Ruta del `application_default_credentials.json` vivo |
| `_gcp_adc_quota_project` | lee archivo | `quota_project_id` de la ADC viva; vacío si falta archivo/clave/jq |
| `_gcp_adc_status <proy> <quota>` | puro | Línea `adc …` + aviso si ambos no vacíos y difieren |
| `_gcp_adc_install <cuenta> <proy>` | escribe | Copia guardada→viva + parche de quota con jq |
| `_gcp_adc_save <cuenta>` | escribe | Copia viva→guardada (la usa `gcx adc`) |
| `_gcp_adc_login` | interactivo | Envuelve el login + save + parche; **única función sin test** |

## Casos borde

- Sin archivo ADC vivo, sin `quota_project_id`, o sin `jq` → `adc —`, sin
  aviso, `gcx use` no intenta parchear.
- Proyecto activo vacío (config sin proyecto) → se instala la ADC de la
  cuenta pero no se toca `quota_project_id`; `who` no avisa (no hay
  comparación posible y la carencia ya se ve en `proyecto —`).
- Cuenta activa vacía (config rota) → `gcx use` no instala nada y no avisa
  de ADC (el fallo visible es de la config, no de las ADC).
- `jq` ausente → todo degrada a no-op silencioso salvo el aviso de
  «no hay ADC guardadas», que no depende de jq.
- Dos configs de la misma cuenta (itproject/kelova): comparten ADC guardada;
  solo cambia el parche de `quota_project_id`.

## Seguridad

- Almacén con 700/600; nunca dentro del repo (regla del repo: llaves y
  credenciales jamás en dotfiles).
- El parcheo jq escribe a temporal en el mismo directorio + `mv` (atómico,
  no deja la ADC viva a medias) y el temporal nace con permisos 600.

## Tests

En `config/zsh/gcp.test.zsh`, conservando la propiedad de correr sin gcloud
ni red:

- `_gcp_adc_quota_project`: archivo válido, ausente, sin clave — con
  `CLOUDSDK_CONFIG` apuntando a un temporal.
- `_gcp_adc_status`: coincide, difiere, un lado vacío.
- `_gcp_adc_install`: instala y parchea quota; sin proyecto no parchea; sin
  ADC guardada no toca la viva; permisos 600 del resultado.
- `_gcp_adc_save`: copia y permisos.
- `gcx use` con stub de gcloud: con ADC guardada instala; sin ella emite el
  aviso con `gcx adc`.

## Fuera de alcance

- Identificar la **cuenta** exacta de la ADC viva (el campo `account` del
  JSON viene vacío; saberlo exige una llamada de red a tokeninfo). El aviso
  compara `quota_project_id` contra el proyecto activo: caza el caso real
  sin coste. Con el intercambio automático, además, el desajuste pasa a ser
  la excepción y no el estado permanente.
- Exportar `GOOGLE_APPLICATION_CREDENTIALS` por sesión: descartado, solo
  afectaría al shell que corre `gcx` y las demás sesiones seguirían con la
  ADC vieja — la misma sorpresa silenciosa que motiva este trabajo.
- Impersonación de service accounts.
