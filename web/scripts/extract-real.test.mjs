import { test } from 'node:test'
import assert from 'node:assert/strict'
import { extraerTodo, RAIZ_REPO } from './extract-tools.mjs'

const datos = extraerTodo(RAIZ_REPO)
const nombres = new Set(datos.entradas.map((e) => e.nombre))
const claves = new Set(datos.entradas.map((e) => e.clave))

test('ninguna clave duplicada', () => {
  assert.equal(datos.entradas.length, claves.size)
})

test('las cinco que no pasan por install_if_missing siguen apareciendo', () => {
  // kubectl, helm, kubectx, kubens y tofu se instalan con bloques
  // `if ! command -v x` a medida. Un parser que solo mirase
  // install_if_missing las omitiría sin dar ningún error.
  for (const n of ['kubectl', 'helm', 'kubectx', 'kubens', 'tofu']) {
    assert.ok(nombres.has(n), `${n} desapareció del extractor de lib/binaries.sh`)
  }
})

test('el gating de lib/binaries.sh clasifica bien', () => {
  const porNombre = Object.fromEntries(
    datos.entradas.filter((e) => e.tipo === 'github').map((e) => [e.nombre, e.modulo]),
  )
  assert.equal(porNombre.k9s, 'k8s')
  assert.equal(porNombre.kubectl, 'k8s')
  assert.equal(porNombre.tofu, 'cloud')
  assert.equal(porNombre.tflint, 'cloud')
  assert.equal(porNombre.lazygit, 'base')
})

test('las seis fuentes aportan entradas', () => {
  for (const fuente of ['Brewfile', 'Brewfile.cloud', 'Brewfile.k8s', 'Brewfile.gui',
                        'lib/binaries.sh', 'lib/packages.sh']) {
    assert.ok((datos.conteos[fuente] ?? 0) > 0, `${fuente} no aportó ninguna entrada`)
  }
})

test('los cinco presets se leen de install.sh', () => {
  const flags = datos.presets.map((p) => p.flag).sort()
  assert.deepEqual(flags, ['--agent', '--container', '--k8s-node', '--minimal', '--vps'])
})

test('--agent hereda cloud y k8s encendidos, y apaga gui', () => {
  const agent = datos.presets.find((p) => p.flag === '--agent')
  assert.deepEqual(agent, { flag: '--agent', cloud: true, k8s: true, gui: false })
})
