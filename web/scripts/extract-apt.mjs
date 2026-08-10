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
