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
