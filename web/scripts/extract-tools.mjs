import { writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { extraerBrew } from './extract-brew.mjs'
import { extraerBinarios } from './extract-binaries.mjs'
import { extraerApt } from './extract-apt.mjs'
import { extraerPresets } from './extract-presets.mjs'

export const RAIZ_REPO = join(import.meta.dirname, '..', '..')
export const DESTINO = join(import.meta.dirname, '..', 'src', 'data', 'tools.generated.json')

/**
 * Reúne las cuatro fuentes en el modelo que consume la web.
 * @param {string} rutaRepo raíz del repo
 * @returns {import('../src/data/types.ts').Generado}
 */
export function extraerTodo(rutaRepo) {
  const entradas = [
    ...extraerBrew(rutaRepo),
    ...extraerBinarios(rutaRepo),
    ...extraerApt(rutaRepo),
  ].sort((a, b) => a.clave.localeCompare(b.clave))

  const conteos = {}
  for (const e of entradas) conteos[e.fuente] = (conteos[e.fuente] ?? 0) + 1

  return { entradas, presets: extraerPresets(rutaRepo), conteos }
}

/** Serialización estable: mismo repo, mismo byte. */
export function serializar(generado) {
  return JSON.stringify(generado, null, 2) + '\n'
}

if (process.argv[1] === import.meta.filename) {
  const generado = extraerTodo(RAIZ_REPO)
  writeFileSync(DESTINO, serializar(generado))
  console.log(
    `tools.generated.json: ${generado.entradas.length} entradas, ` +
      `${generado.presets.length} presets`,
  )
  for (const [fuente, n] of Object.entries(generado.conteos)) {
    console.log(`  ${fuente}: ${n}`)
  }
}
