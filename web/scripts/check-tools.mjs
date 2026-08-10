import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { extraerTodo, serializar, RAIZ_REPO, DESTINO } from './extract-tools.mjs'

const CURADO = join(import.meta.dirname, '..', 'src', 'data', 'tools.curated.json')

// Suelo por fuente. Existen porque el parser es regex sobre bash y "dejar de
// ver" una herramienta no produce ningún error: sin esto, romper la forma de las
// arrays de binaries.sh publicaría un catálogo mutilado con el CI en verde.
//
// Calibrados al ~75% del recuento real, no a un pelo por debajo. Lo que tienen
// que cazar es que el parser deje de casar —eso tumba el conteo a la mitad o a
// cero—, no que retires una herramienta a propósito. Un suelo pegado al valor
// real convierte cada retirada legítima en un build rojo, y una guardia que da
// falsos positivos es una guardia que se acaba bajando sin mirar.
//
// Se suben al añadir herramientas y SOLO se bajan a mano, en el mismo commit que
// retira la herramienta y explicando por qué. Bajarlos para poner verde un build
// rojo es desactivar la guardia.
//
// Recuentos reales al escribir esto: Brewfile 73, .cloud 9, .k8s 15, .gui 32,
// binaries.sh 31, packages.sh 27.
export const MINIMOS = {
  'Brewfile': 55,
  'Brewfile.cloud': 7,
  'Brewfile.k8s': 11,
  'Brewfile.gui': 24,
  'lib/binaries.sh': 23,
  'lib/packages.sh': 20,
}

const CAMPOS = ['id', 'nombre', 'categoria', 'descripcion', 'url']

/**
 * Comprueba la forma de las fichas curadas: que tengan los campos que la UI
 * lee, que declaren al menos una clave y que no repitan `id`.
 *
 * Va aparte de las comprobaciones contra el repo porque son dos preguntas
 * distintas: aquéllas miran la RELACIÓN entre ficha y repo, y ésta mira la
 * ficha en sí. Sin ésta, el checker prometía en su propio mensaje de error
 * "añade una ficha con nombre, categoria, descripcion y url" y luego no
 * comprobaba ninguno de los cuatro.
 *
 * Devuelve la lista de errores; vacía si todo está bien.
 */
export function validarFichas(curadas) {
  const errores = []
  const ids = new Map()

  for (const [i, ficha] of curadas.entries()) {
    const donde = typeof ficha?.id === 'string' && ficha.id ? `"${ficha.id}"` : `#${i}`

    for (const campo of CAMPOS) {
      if (typeof ficha?.[campo] !== 'string' || !ficha[campo].trim()) {
        errores.push(`La ficha ${donde} no tiene \`${campo}\`.`)
      }
    }

    // Una ficha sin claves no la caza ninguna de las otras comprobaciones: no es
    // huérfana (no le falta ficha a nadie) ni fantasma (no declara nada que
    // sobre). Pero sale en el catálogo sin badges y `cuentaDePreset` la excluye
    // de los cinco presets, porque no la respalda ninguna entrada del repo.
    if (!Array.isArray(ficha?.declarado) || ficha.declarado.length === 0) {
      errores.push(
        `La ficha ${donde} no declara ninguna clave.\n` +
          '  Saldría en el catálogo sin respaldo en el repo y fuera de todos los presets.',
      )
    }

    if (typeof ficha?.id === 'string' && ficha.id) {
      const previa = ids.get(ficha.id)
      if (previa !== undefined) {
        errores.push(
          `Dos fichas comparten el id "${ficha.id}" (posiciones ${previa} y ${i}).\n` +
            '  El `id` es la clave de React del catálogo, así que tiene que ser único.',
        )
      } else {
        ids.set(ficha.id, i)
      }
    }
  }

  return errores
}

/** Mapa clave -> ficha que la declara, acumulando los choques en `errores`. */
function indexarDeclaradas(curadas, errores) {
  const declaradas = new Map()

  for (const [i, ficha] of curadas.entries()) {
    if (!Array.isArray(ficha?.declarado)) continue
    for (const clave of ficha.declarado) {
      const previa = declaradas.get(clave)
      if (previa) {
        errores.push(
          previa.i === i
            ? `${clave} aparece dos veces en el \`declarado\` de la ficha "${ficha.id}".`
            : `${clave} lo declaran dos fichas curadas: "${previa.id}" y "${ficha.id}".`,
        )
      } else {
        declaradas.set(clave, { id: ficha.id, i })
      }
    }
  }

  return declaradas
}

function main() {
  const errores = []

  const generado = extraerTodo(RAIZ_REPO)
  const enDisco = readFileSync(DESTINO, 'utf8')

  if (serializar(generado) !== enDisco) {
    errores.push(
      'tools.generated.json está desincronizado con el repo.\n' +
        '  Corre `npm run extract` y commitea el resultado.',
    )
  }

  // El curado es el único fichero de este flujo escrito a mano, o sea el único que
  // puede llegar malformado. Se parsea dentro de un try para que un error de
  // sintaxis no se lleve por delante los avisos ya acumulados: si el JSON generado
  // está rancio Y el curado roto, hay que ver las dos cosas de una vez, no
  // arreglar una y volver a chocar con la otra.
  let curadas = null
  try {
    curadas = JSON.parse(readFileSync(CURADO, 'utf8'))
    if (!Array.isArray(curadas)) {
      throw new Error('la raíz del fichero no es un array de fichas')
    }
  } catch (e) {
    curadas = null
    errores.push(`tools.curated.json no se puede leer: ${e.message}`)
  }

  if (curadas) {
    errores.push(...validarFichas(curadas))

    const declaradas = indexarDeclaradas(curadas, errores)
    const existentes = new Set(generado.entradas.map((e) => e.clave))

    const huerfanas = [...existentes].filter((c) => !declaradas.has(c))
    if (huerfanas.length) {
      errores.push(
        `${huerfanas.length} herramienta(s) del repo sin ficha en tools.curated.json:\n` +
          huerfanas.map((c) => `    ${c}`).join('\n') +
          '\n  Añade una ficha con nombre, categoria, descripcion y url.',
      )
    }

    const fantasmas = [...declaradas.keys()].filter((c) => !existentes.has(c))
    if (fantasmas.length) {
      errores.push(
        `${fantasmas.length} ficha(s) curada(s) declaran algo que el repo ya no instala:\n` +
          fantasmas.map((c) => `    ${c} (ficha "${declaradas.get(c).id}")`).join('\n') +
          '\n  Quita la ficha, o la clave sobrante de su `declarado`.',
      )
    }
  }

  for (const [fuente, minimo] of Object.entries(MINIMOS)) {
    const real = generado.conteos[fuente] ?? 0
    if (real < minimo) {
      errores.push(
        `${fuente}: ${real} entradas, por debajo del mínimo de ${minimo}.\n` +
          '  O el parser dejó de casar, o se retiraron herramientas. Si fue lo\n' +
          '  segundo, baja el mínimo en check-tools.mjs en ese mismo commit.',
      )
    }
  }

  if (errores.length) {
    console.error('\n✖ check-tools:\n')
    for (const e of errores) console.error('  ' + e + '\n')
    process.exit(1)
  }

  console.log(
    `✔ check-tools: ${generado.entradas.length} entradas cubiertas por ${curadas.length} fichas.`,
  )
}

// Igual que en extract-tools.mjs: el cuerpo solo corre al invocar el fichero
// como script. Sin esta guarda, importar `validarFichas` desde un test
// ejecutaria el checker entero, incluido su process.exit.
if (process.argv[1] === import.meta.filename) {
  main()
}
