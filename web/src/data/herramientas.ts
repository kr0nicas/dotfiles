import type { Curada, Entrada, Generado, Herramienta, Modulo, Plataforma, Preset } from './types'
import generado from './tools.generated.json'
import curadas from './tools.curated.json'

const datos = generado as Generado
const fichas = curadas as Curada[]

const porClave = new Map<string, Entrada>(datos.entradas.map((e) => [e.clave, e]))

/** Una ficha curada + las entradas reales que la respaldan. */
export const herramientas: Herramienta[] = fichas
  .map(({ declarado, ...ficha }) => {
    const entradas = declarado.map((c) => porClave.get(c)).filter((e): e is Entrada => Boolean(e))
    return {
      ...ficha,
      entradas,
      modulos: [...new Set(entradas.map((e) => e.modulo))] as Modulo[],
      plataformas: [...new Set(entradas.map((e) => e.plataforma))] as Plataforma[],
    }
  })
  .sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'))

export const presets: Preset[] = datos.presets

export const categorias: string[] = [...new Set(herramientas.map((h) => h.categoria))].sort((a, b) =>
  a.localeCompare(b, 'es'),
)

/** Cuántas herramientas trae un preset. El recuento sale del catálogo, no de una constante. */
export function cuentaDePreset(preset: Preset): number {
  return herramientas.filter((h) =>
    h.modulos.some(
      (m) =>
        m === 'base' ||
        (m === 'cloud' && preset.cloud) ||
        (m === 'k8s' && preset.k8s) ||
        (m === 'gui' && preset.gui),
    ),
  ).length
}
