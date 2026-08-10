import { test } from 'node:test'
import assert from 'node:assert/strict'
import { validarFichas } from './check-tools.mjs'

/** Ficha válida mínima; los tests la clonan y le rompen una cosa cada vez. */
function ficha(extra = {}) {
  return {
    id: 'fd',
    nombre: 'fd',
    categoria: 'CLI moderna',
    descripcion: 'Busca ficheros por nombre.',
    url: 'https://github.com/sharkdp/fd',
    declarado: ['brew:fd'],
    ...extra,
  }
}

test('una ficha completa no da errores', () => {
  assert.deepEqual(validarFichas([ficha()]), [])
})

// Los cuatro campos que la UI lee. El checker los nombraba en su mensaje de
// error ("añade una ficha con nombre, categoria, descripcion y url") y no
// comprobaba ninguno: una ficha sin `nombre` reventaba el sort de
// herramientas.ts, y el cast `as Curada[]` impedía que tsc lo cazara.
for (const campo of ['id', 'nombre', 'categoria', 'descripcion', 'url']) {
  test(`una ficha sin \`${campo}\` da error`, () => {
    const rota = ficha()
    delete rota[campo]
    const errores = validarFichas([rota])
    assert.equal(errores.length, 1, `esperaba 1 error, salieron ${errores.length}`)
    assert.match(errores[0], new RegExp(`\`${campo}\``))
  })

  test(`\`${campo}\` en blanco cuenta como ausente`, () => {
    assert.equal(validarFichas([ficha({ [campo]: '   ' })]).length, 1)
  })
}

test('un campo que no es cadena da error', () => {
  assert.equal(validarFichas([ficha({ nombre: 42 })]).length, 1)
})

// Una ficha sin claves no la caza ninguna otra comprobación: no es huérfana ni
// fantasma. Pero saldría en el catálogo sin badges y fuera de los cinco presets.
test('una ficha con `declarado` vacío da error', () => {
  const errores = validarFichas([ficha({ declarado: [] })])
  assert.equal(errores.length, 1)
  assert.match(errores[0], /no declara ninguna clave/)
})

test('una ficha sin campo `declarado` da error y no lanza', () => {
  const rota = ficha()
  delete rota.declarado
  const errores = validarFichas([rota])
  assert.equal(errores.length, 1)
  assert.match(errores[0], /no declara ninguna clave/)
})

test('`declarado` que no es array da error', () => {
  assert.equal(validarFichas([ficha({ declarado: 'brew:fd' })]).length, 1)
})

// El `id` es la key de React del catálogo. Era lo único que identifica la ficha
// y lo único que no se validaba.
test('dos fichas con el mismo id dan error', () => {
  const errores = validarFichas([ficha(), ficha({ declarado: ['brew:otro'] })])
  assert.equal(errores.length, 1)
  assert.match(errores[0], /comparten el id "fd"/)
  assert.match(errores[0], /posiciones 0 y 1/)
})

test('dos fichas con ids distintos no dan error', () => {
  assert.deepEqual(validarFichas([ficha(), ficha({ id: 'rg', declarado: ['brew:ripgrep'] })]), [])
})

test('una ficha sin id se localiza por posición, no por id', () => {
  const rota = ficha()
  delete rota.id
  const errores = validarFichas([ficha({ id: 'otra' }), rota])
  assert.equal(errores.length, 1)
  assert.match(errores[0], /#1/)
})

test('acumula todos los errores de una misma ficha', () => {
  const errores = validarFichas([{ id: 'x' }])
  // faltan nombre, categoria, descripcion, url y declarado
  assert.equal(errores.length, 5)
})

test('una lista vacía de fichas no da errores', () => {
  assert.deepEqual(validarFichas([]), [])
})
