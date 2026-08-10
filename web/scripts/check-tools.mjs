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
const MINIMOS = {
  'Brewfile': 55,
  'Brewfile.cloud': 7,
  'Brewfile.k8s': 11,
  'Brewfile.gui': 24,
  'lib/binaries.sh': 23,
  'lib/packages.sh': 20,
}

const errores = []

const generado = extraerTodo(RAIZ_REPO)
const enDisco = readFileSync(DESTINO, 'utf8')

if (serializar(generado) !== enDisco) {
  errores.push(
    'tools.generated.json está desincronizado con el repo.\n' +
      '  Corre `npm run extract` y commitea el resultado.',
  )
}

const curadas = JSON.parse(readFileSync(CURADO, 'utf8'))

const declaradas = new Map()
for (const ficha of curadas) {
  for (const clave of ficha.declarado) {
    const previa = declaradas.get(clave)
    if (previa) {
      errores.push(`${clave} lo declaran dos fichas curadas: "${previa}" y "${ficha.id}".`)
    }
    declaradas.set(clave, ficha.id)
  }
}

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
      fantasmas.map((c) => `    ${c} (ficha "${declaradas.get(c)}")`).join('\n') +
      '\n  Quita la ficha, o la clave sobrante de su `declarado`.',
  )
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
  `✔ check-tools: ${existentes.size} entradas cubiertas por ${curadas.length} fichas.`,
)
