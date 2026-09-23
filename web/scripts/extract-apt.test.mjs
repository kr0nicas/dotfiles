import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerApt } from './extract-apt.mjs'

function repoFalso(contenido) {
  const dir = mkdtempSync(join(tmpdir(), 'apttest-'))
  mkdirSync(join(dir, 'lib'))
  writeFileSync(join(dir, 'lib/packages.sh'), contenido)
  return dir
}

const GUION = `
phase_packages() {
            sudo apt update
            sudo apt install -y zsh tmux git curl jq \\
                zsh-autosuggestions bsdextrautils 2>/dev/null || true

            sudo DEBIAN_FRONTEND=noninteractive apt install -y \\
                mtr-tiny nmap socat 2>/dev/null || true

            if [[ $INSTALL_CLOUD -eq 1 ]]; then
                sudo apt install -y postgresql-client 2>/dev/null || true
            fi
}
`

test('extrae los paquetes de todas las invocaciones de apt install', () => {
  const nombres = extraerApt(repoFalso(GUION)).map((e) => e.nombre).sort()

  assert.deepEqual(nombres, [
    'bsdextrautils', 'curl', 'git', 'jq', 'mtr-tiny', 'nmap',
    'postgresql-client', 'socat', 'tmux', 'zsh', 'zsh-autosuggestions',
  ])
})

test('respeta el gating de cloud y descarta el ruido de la línea', () => {
  const porNombre = Object.fromEntries(
    extraerApt(repoFalso(GUION)).map((e) => [e.nombre, e]),
  )

  assert.equal(porNombre['zsh'].modulo, 'base')
  assert.equal(porNombre['postgresql-client'].modulo, 'cloud')
  assert.equal(porNombre['zsh'].plataforma, 'linux')
  assert.equal(porNombre['zsh'].tipo, 'apt')
  assert.equal(porNombre['zsh'].clave, 'apt:zsh')
  // `2>/dev/null`, `||`, `true` y `-y` no son paquetes.
  assert.equal(porNombre['true'], undefined)
  assert.equal(porNombre['-y'], undefined)
})

test('reconoce el helper apt_install y no su definición', () => {
  const guion = [
    'apt_install() {',
    '    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null 2>&1 && return 0',
    '}',
    'phase_packages() {',
    '            apt_install zsh tmux \\',
    '                gcc make',
    '            apt_install faketime',
    '}',
  ].join('\n')
  const nombres = extraerApt(repoFalso(guion)).map((e) => e.nombre).sort()
  assert.deepEqual(nombres, ['faketime', 'gcc', 'make', 'tmux', 'zsh'])
})

test('ignora apt update, que no instala nada', () => {
  const nombres = extraerApt(repoFalso('sudo apt update\n')).map((e) => e.nombre)
  assert.deepEqual(nombres, [])
})
