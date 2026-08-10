import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerBrew } from './extract-brew.mjs'

function repoFalso(ficheros) {
  const dir = mkdtempSync(join(tmpdir(), 'brewtest-'))
  for (const [nombre, contenido] of Object.entries(ficheros)) {
    writeFileSync(join(dir, nombre), contenido)
  }
  return dir
}

test('extrae brew, cask y vscode con su categoría', () => {
  const dir = repoFalso({
    'Brewfile': [
      '# --- Core CLI ---',
      'brew "git"',
      'brew "tmux"',
      '',
      '# --- Modern CLI (Rust-powered) ---',
      'brew "bat"',
      'cask "wezterm"',
    ].join('\n'),
    'Brewfile.cloud': '# --- Cloud CLIs ---\nbrew "awscli"\n',
    'Brewfile.k8s': '# --- Kubernetes core ---\nbrew "kubectl"\n',
    'Brewfile.gui': '# --- VS Code Extensions ---\nvscode "golang.go"\n',
  })

  const entradas = extraerBrew(dir)
  const porClave = Object.fromEntries(entradas.map((e) => [e.clave, e]))

  assert.equal(entradas.length, 7)
  assert.deepEqual(porClave['brew:bat'], {
    clave: 'brew:bat',
    nombre: 'bat',
    tipo: 'brew',
    modulo: 'base',
    plataforma: 'macos',
    fuente: 'Brewfile',
    categoriaBrewfile: 'Modern CLI (Rust-powered)',
  })
  assert.equal(porClave['cask:wezterm'].tipo, 'cask')
  assert.equal(porClave['brew:awscli'].modulo, 'cloud')
  assert.equal(porClave['brew:kubectl'].modulo, 'k8s')
  assert.equal(porClave['vscode:golang.go'].modulo, 'gui')
})

test('ignora comentarios, taps y líneas en blanco', () => {
  const dir = repoFalso({
    'Brewfile': [
      '# comentario suelto',
      'tap "hashicorp/tap"',
      '',
      '   brew "jq"   ',
      '# brew "comentado"',
    ].join('\n'),
    'Brewfile.cloud': '',
    'Brewfile.k8s': '',
    'Brewfile.gui': '',
  })

  const entradas = extraerBrew(dir)
  assert.deepEqual(entradas.map((e) => e.clave), ['brew:jq'])
})

test('rechaza una fórmula declarada en dos Brewfiles', () => {
  const dir = repoFalso({
    'Brewfile': 'brew "jq"\n',
    'Brewfile.cloud': 'brew "jq"\n',
    'Brewfile.k8s': '',
    'Brewfile.gui': '',
  })

  assert.throws(() => extraerBrew(dir), /brew:jq.*Brewfile.*Brewfile\.cloud/s)
})
