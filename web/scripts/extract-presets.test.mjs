import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerPresets } from './extract-presets.mjs'

function repoFalso(contenido) {
  const dir = mkdtempSync(join(tmpdir(), 'presettest-'))
  writeFileSync(join(dir, 'install.sh'), contenido)
  return dir
}

const GUION = `
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=1 ;;
        --minimal)   INSTALL_CLOUD=0; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --vps)       INSTALL_CLOUD=1; INSTALL_K8S=0; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --k8s-node)  INSTALL_CLOUD=1; INSTALL_K8S=1; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --agent)     INSTALL_AGENT=1; INSTALL_GUI=0; PROFILE_FLAG=1 ;;
        --no-cloud)  INSTALL_CLOUD=0; PROFILE_FLAG=1 ;;
    esac
done
`

test('extrae solo los presets, no las flags sueltas', () => {
  const flags = extraerPresets(repoFalso(GUION)).map((p) => p.flag)
  assert.deepEqual(flags, ['--minimal', '--vps', '--k8s-node', '--agent'])
})

test('lee los módulos que enciende cada preset', () => {
  const porFlag = Object.fromEntries(extraerPresets(repoFalso(GUION)).map((p) => [p.flag, p]))

  assert.deepEqual(porFlag['--vps'], { flag: '--vps', cloud: true, k8s: false, gui: false })
  assert.deepEqual(porFlag['--k8s-node'], { flag: '--k8s-node', cloud: true, k8s: true, gui: false })
})

test('--agent hereda cloud y k8s encendidos porque no los toca', () => {
  // No es un descuido del parser: --agent es ortogonal a la carga de la
  // máquina, así que deja cloud y k8s en su valor por defecto (1).
  const agent = extraerPresets(repoFalso(GUION)).find((p) => p.flag === '--agent')
  assert.deepEqual(agent, { flag: '--agent', cloud: true, k8s: true, gui: false })
})
