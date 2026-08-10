import { test } from 'node:test'
import assert from 'node:assert/strict'
import { crearGating } from './gating.mjs'

/** Recorre un guion y devuelve [linea, modulo] de las líneas NO consumidas. */
function recorrer(guion) {
  const g = crearGating('fichero-de-prueba')
  const salida = []
  for (const linea of guion.split('\n')) {
    if (g.procesar(linea)) continue
    if (linea.trim()) salida.push([linea.trim(), g.modulo()])
  }
  return salida
}

test('fuera de todo bloque el módulo es base', () => {
  assert.deepEqual(recorrer('herramienta_a'), [['herramienta_a', 'base']])
})

test('dentro de un bloque de gating el módulo es el del bloque', () => {
  const guion = [
    '        if [[ $INSTALL_K8S -eq 1 ]]; then',
    '            herramienta_a',
    '        fi',
    '        herramienta_b',
  ].join('\n')

  assert.deepEqual(recorrer(guion), [['herramienta_a', 'k8s'], ['herramienta_b', 'base']])
})

test('un if anidado no cierra el bloque de gating', () => {
  const guion = [
    '        if [[ $INSTALL_CLOUD -eq 1 ]]; then',
    '            if ! command -v x >/dev/null 2>&1; then',
    '                herramienta_a',
    '            fi',
    '            herramienta_b',
    '        fi',
  ].join('\n')

  assert.deepEqual(recorrer(guion), [
    ['if ! command -v x >/dev/null 2>&1; then', 'cloud'],
    ['herramienta_a', 'cloud'],
    ['herramienta_b', 'cloud'],
  ])
})

test('en la rama else el módulo es null: ahí vive el camino de no instalar', () => {
  const guion = [
    '        if [[ $INSTALL_K8S -eq 1 ]]; then',
    '            herramienta_a',
    '        else',
    '            herramienta_b',
    '        fi',
    '        herramienta_c',
  ].join('\n')

  assert.deepEqual(recorrer(guion), [
    ['herramienta_a', 'k8s'],
    ['herramienta_b', null],
    ['herramienta_c', 'base'],
  ])
})

test('un else más indentado que el bloque no es el suyo', () => {
  const guion = [
    '        if [[ $INSTALL_K8S -eq 1 ]]; then',
    '            if ! command -v x >/dev/null 2>&1; then',
    '                herramienta_a',
    '            else',
    '                herramienta_b',
    '            fi',
    '        fi',
  ].join('\n')

  const modulos = recorrer(guion).map(([, m]) => m)
  assert.ok(modulos.every((m) => m === 'k8s'), `esperaba todo k8s, salió ${modulos.join()}`)
})

test('un fi por fuera del bloque abierto lanza en vez de cerrar en silencio', () => {
  const guion = [
    '        if [[ $INSTALL_K8S -eq 1 ]]; then',
    '            herramienta_a',
    '    fi',
  ].join('\n')

  assert.throws(() => recorrer(guion), /fichero-de-prueba.*columna/s)
})
