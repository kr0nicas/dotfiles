// Máquina de estados del gating por módulos, compartida por los extractores de
// lib/binaries.sh y lib/packages.sh. Los dos ficheros usan la misma forma
// (`if [[ $INSTALL_K8S -eq 1 ]]` … `else` … `fi`) y tenerla dos veces significaba
// arreglar cada defecto dos veces.

const APERTURA = /^(\s*)if\s+\[\[\s+\$INSTALL_(K8S|CLOUD)\s+-eq\s+1\s+\]\]/
const ELSE = /^(\s*)else\b/
const CIERRE = /^(\s*)fi\b/

/**
 * @param {string} fuente ruta del fichero, solo para los mensajes de error
 * @returns {{procesar: (linea: string) => boolean, modulo: () => 'base'|'cloud'|'k8s'|null}}
 */
export function crearGating(fuente) {
  /** @type {{sangria: number, modulo: 'k8s'|'cloud', enElse: boolean}[]} */
  const pila = []

  return {
    procesar(linea) {
      // El cierre va primero: un `fi` a la columna del `if` de gating lo cierra;
      // uno más indentado pertenece a un if anidado y no es nuestro.
      const cierre = linea.match(CIERRE)
      if (cierre && pila.length) {
        const cima = pila[pila.length - 1]
        if (cierre[1].length === cima.sangria) {
          pila.pop()
          return true
        }
        if (cierre[1].length < cima.sangria) {
          // Antes esto cerraba el bloque igualmente (`<=`). Un `fi` por fuera del
          // `if` que lo abrió no es un anidamiento: es que la estructura del
          // fichero cambió y el parser ya no la entiende. Fallar ruidoso, porque
          // el modo de fallo silencioso es publicar módulos equivocados.
          throw new Error(
            `${fuente}: un \`fi\` en la columna ${cierre[1].length} cierra por fuera del ` +
              `bloque \`$INSTALL_${cima.modulo.toUpperCase()}\` abierto en la columna ` +
              `${cima.sangria}. Revisa el fichero y el parser.`,
          )
        }
        // Más indentado: cierra un if anidado (no de gating, p.ej. un
        // `if ! command -v x`) que abrió y cerró por dentro del bloque. No es
        // nuestro `fi`, pero tampoco es una línea de contenido — se traga en
        // silencio en vez de dejarla salir como si fuera código suelto.
        return true
      }

      const apertura = linea.match(APERTURA)
      if (apertura) {
        pila.push({
          sangria: apertura[1].length,
          modulo: apertura[2] === 'K8S' ? 'k8s' : 'cloud',
          enElse: false,
        })
        return true
      }

      const rama = linea.match(ELSE)
      if (rama && pila.length && rama[1].length === pila[pila.length - 1].sangria) {
        pila[pila.length - 1].enElse = true
        return true
      }

      return false
    },

    modulo() {
      if (!pila.length) return 'base'
      // Cualquier marco en su rama `else` invalida lo de dentro: ahí vive el
      // camino de *no* instalar, no una declaración.
      if (pila.some((m) => m.enElse)) return null
      return pila[pila.length - 1].modulo
    },
  }
}
