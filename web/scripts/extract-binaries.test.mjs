import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { extraerBinarios } from './extract-binaries.mjs'

function repoFalso(contenido) {
  const dir = mkdtempSync(join(tmpdir(), 'bintest-'))
  mkdirSync(join(dir, 'lib'))
  writeFileSync(join(dir, 'lib/binaries.sh'), contenido)
  return dir
}

const GUION = `
phase_binaries() {
    if [[ $IS_MAC -eq 0 ]]; then
        install_if_missing "lazygit" \\
            "gh_latest_tar jesseduffield/lazygit 'linux.tar.gz' $LOCAL_BIN lazygit"

        install_if_missing "yamllint" "uv tool install yamllint"

        if [[ $INSTALL_K8S -eq 1 ]]; then
            install_if_missing "k9s" \\
                "gh_latest_tar derailed/k9s 'Linux.tar.gz' $LOCAL_BIN k9s"

            if ! command -v kubectl >/dev/null 2>&1; then
                log "Instalando kubectl..."
            else
                ok "kubectl ya instalado"
            fi

            if ! command -v kubectx >/dev/null 2>&1; then
                gh_latest_tar ahmetb/kubectx "kubectx_linux.tar.gz" "$LOCAL_BIN" kubectx
                gh_latest_tar ahmetb/kubectx "kubens_linux.tar.gz" "$LOCAL_BIN" kubens
            fi
        else
            warn "Skipping k8s"
        fi

        if [[ $INSTALL_CLOUD -eq 1 ]]; then
            install_if_missing "tflint" \\
                "gh_latest_zip terraform-linters/tflint 'linux.zip' $LOCAL_BIN"

            if ! command -v tofu >/dev/null 2>&1; then
                log "Instalando OpenTofu..."
            fi
        fi
    fi
}
`

test('caza los tres patrones de declaración', () => {
  const entradas = extraerBinarios(repoFalso(GUION))
  const nombres = entradas.map((e) => e.nombre).sort()

  assert.deepEqual(nombres, [
    'k9s', 'kubectl', 'kubectx', 'kubens', 'lazygit', 'tflint', 'tofu', 'yamllint',
  ])
})

test('asigna el módulo según el bloque que envuelve la línea', () => {
  const porNombre = Object.fromEntries(
    extraerBinarios(repoFalso(GUION)).map((e) => [e.nombre, e.modulo]),
  )

  assert.equal(porNombre.lazygit, 'base')
  assert.equal(porNombre.yamllint, 'base')
  assert.equal(porNombre.k9s, 'k8s')
  assert.equal(porNombre.kubectl, 'k8s')
  assert.equal(porNombre.kubens, 'k8s')
  assert.equal(porNombre.tflint, 'cloud')
  assert.equal(porNombre.tofu, 'cloud')
})

test('los if anidados no cierran el bloque de gating', () => {
  // tofu vive tras un if/fi anidado dentro del bloque cloud. Si el parser
  // cerrara el gating con el primer `fi` que ve, tofu saldría como base.
  const porNombre = Object.fromEntries(
    extraerBinarios(repoFalso(GUION)).map((e) => [e.nombre, e.modulo]),
  )
  assert.equal(porNombre.tofu, 'cloud')
})

test('marca todo como linux, github y con clave prefijada', () => {
  const lazygit = extraerBinarios(repoFalso(GUION)).find((e) => e.nombre === 'lazygit')

  assert.equal(lazygit.plataforma, 'linux')
  assert.equal(lazygit.tipo, 'github')
  assert.equal(lazygit.clave, 'github:lazygit')
  assert.equal(lazygit.fuente, 'lib/binaries.sh')
})

test('no duplica una herramienta declarada por dos patrones', () => {
  const dir = repoFalso(`
        install_if_missing "kubectx" "algo"
        if ! command -v kubectx >/dev/null 2>&1; then
            gh_latest_tar ahmetb/kubectx "x.tar.gz" "$LOCAL_BIN" kubectx
        fi
`)
  assert.deepEqual(extraerBinarios(dir).map((e) => e.nombre), ['kubectx'])
})
