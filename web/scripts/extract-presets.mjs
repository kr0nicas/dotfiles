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
