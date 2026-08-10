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
  // Aquí SÍ vale localeCompare, al revés que en extract-tools.mjs. Allí está
  // prohibido porque check-tools compara el JSON byte a byte contra una
  // extracción fresca, así que un ICU distinto da un build rojo irreproducible.
  // Este orden no se serializa ni se diffea: es presentación. Y las categorías
  // llevan tildes («Red y diagnóstico»), donde el orden lingüístico es el
  // correcto y el ordinal mandaría al final cualquier categoría con acento.
  //
  // La exención depende de que este módulo se importe solo desde servidor. Si un
  // 'use client' lo importa, el mismo sort corre en dos ICU distintos —y además
  // se lleva el catálogo entero al navegador; ver PresetConCuenta en types.ts.
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
