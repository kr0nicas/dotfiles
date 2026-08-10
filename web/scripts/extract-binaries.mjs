import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { crearGating } from './gating.mjs'

const FUENTE = 'lib/binaries.sh'

// Los tres patrones con los que binaries.sh declara una herramienta.
// Mirar solo el primero deja fuera kubectl, helm, kubectx, kubens y tofu.
const INSTALL_IF_MISSING = /^\s*install_if_missing\s+"([^"]+)"/
const COMMAND_V = /^\s*if\s+!\s+command\s+-v\s+([A-Za-z0-9_.-]+)\s/
// `"$LOCAL_BIN"` entrecomillado: así solo casan las llamadas directas, no las
// que van dentro de la cadena de un install_if_missing (que lo llevan sin
// comillas y ya las coge INSTALL_IF_MISSING).
const GH_DIRECTO = /gh_latest_tar\s+(\S+)\s+"[^"]*"\s+"\$LOCAL_BIN"\s+([A-Za-z0-9_.-]+)/

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

  const gating = crearGating(FUENTE)
  /** @type {Map<string, import('../src/data/types.ts').Entrada>} */
  const porNombre = new Map()

  const registrar = (nombre, repo, modulo) => {
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
      modulo,
      plataforma: 'linux',
      fuente: FUENTE,
    }
    if (repo) entrada.repo = repo
    porNombre.set(nombre, entrada)
  }

  for (const linea of lineas) {
    if (gating.procesar(linea)) continue

    const modulo = gating.modulo()
    // null = rama `else` de un gating: ahí no se instala nada.
    if (modulo === null) continue

    const iim = linea.match(INSTALL_IF_MISSING)
    if (iim) { registrar(iim[1], repoDe(linea), modulo); continue }

    const cmd = linea.match(COMMAND_V)
    if (cmd) { registrar(cmd[1], undefined, modulo); continue }

    const gh = linea.match(GH_DIRECTO)
    if (gh) { registrar(gh[2], gh[1], modulo); continue }
  }

  return [...porNombre.values()]
}
