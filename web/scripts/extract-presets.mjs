import { readFileSync } from 'node:fs'
import { join } from 'node:path'

const FUENTE = 'install.sh'

// Solo las ramas del case que fijan PROFILE_FLAG=1 son presets; --dry-run y
// --update no lo hacen. Las --no-* se excluyen aparte: son modificadores.
const RAMA = /^\s*(--[a-z0-9-]+)\)\s*(.*?)\s*;;/

const DEFAULT = /^INSTALL_(CLOUD|K8S|GUI)=([01])\s*$/

/**
 * Lee las asignaciones por defecto de install.sh. Están a columna 0 y antes del
 * bucle de flags. Leerlas en vez de asumir que valen 1 es lo que evita que la
 * web siga diciendo "cloud=ON" el día que ese default cambie.
 */
function leerDefaults(lineas, fuente) {
  const defaults = {}
  for (const linea of lineas) {
    const m = linea.match(DEFAULT)
    if (m) defaults[m[1]] = m[2] === '1'
  }
  for (const nombre of ['CLOUD', 'K8S', 'GUI']) {
    if (!(nombre in defaults)) {
      throw new Error(
        `${fuente}: no se encontró la asignación por defecto INSTALL_${nombre}=0|1. ` +
          `Sin ella no se puede saber qué hereda un preset que no la menciona.`,
      )
    }
  }
  return defaults
}

/**
 * Lee de install.sh qué módulos enciende cada preset.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Preset[]}
 */
export function extraerPresets(rutaRepo) {
  const lineas = readFileSync(join(rutaRepo, FUENTE), 'utf8').split('\n')
  const defaults = leerDefaults(lineas, FUENTE)
  const presets = []

  for (const linea of lineas) {
    const m = linea.match(RAMA)
    if (!m) continue

    const [, flag, cuerpo] = m
    if (!cuerpo.includes('PROFILE_FLAG=1')) continue
    if (flag.startsWith('--no-')) continue

    // Un preset solo apaga lo que nombra; lo que calla lo hereda del default que
    // declara install.sh. --agent no menciona cloud ni k8s a propósito.
    const leer = (nombre) => {
      const v = cuerpo.match(new RegExp(`INSTALL_${nombre}=([01])`))
      return v ? v[1] === '1' : defaults[nombre]
    }

    presets.push({ flag, cloud: leer('CLOUD'), k8s: leer('K8S'), gui: leer('GUI') })
  }

  return presets
}
