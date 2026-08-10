'use client'

import type { Modulo, Plataforma } from '@/data/types'

export const MODULOS = ['base', 'cloud', 'k8s', 'gui'] as const
export const PLATAFORMAS = ['macos', 'linux'] as const

export interface Filtros {
  q: string
  modulo: Modulo | ''
  plataforma: Plataforma | ''
  categoria: string
}

// La querystring es entrada de fuera: `?m=loquesea` tiene que degradar a "todos"
// y no a "ningún resultado", que parecería el buscador roto. Estas dos guardas
// son además lo que hace que los `includes` de Catalogo typecheen sin castear.
export function comoModulo(v: string): Modulo | '' {
  return (MODULOS as readonly string[]).includes(v) ? (v as Modulo) : ''
}

export function comoPlataforma(v: string): Plataforma | '' {
  return (PLATAFORMAS as readonly string[]).includes(v) ? (v as Plataforma) : ''
}

export function FilterBar({
  filtros,
  categorias,
  onCambio,
  total,
}: {
  filtros: Filtros
  categorias: string[]
  onCambio: (parcial: Partial<Filtros>) => void
  total: number
}) {
  const select = 'rounded-md border border-surface0 bg-mantle px-3 py-2 text-sm text-subtext0'

  return (
    <div className="sticky top-0 z-10 -mx-6 mb-8 border-b border-surface0 bg-base/95 px-6 py-4 backdrop-blur">
      <div className="flex flex-wrap items-center gap-3">
        <input
          type="search"
          value={filtros.q}
          onChange={(e) => onCambio({ q: e.target.value })}
          placeholder="Buscar herramienta…"
          aria-label="Buscar herramienta"
          className="min-w-52 flex-1 rounded-md border border-surface0 bg-mantle px-3 py-2 font-mono text-sm text-text placeholder:text-overlay0 focus:border-lavender focus:outline-none"
        />
        <select
          value={filtros.plataforma}
          onChange={(e) => onCambio({ plataforma: comoPlataforma(e.target.value) })}
          aria-label="Filtrar por plataforma"
          className={select}
        >
          <option value="">Toda plataforma</option>
          <option value="macos">macOS</option>
          <option value="linux">Linux</option>
        </select>
        <select
          value={filtros.modulo}
          onChange={(e) => onCambio({ modulo: comoModulo(e.target.value) })}
          aria-label="Filtrar por módulo"
          className={select}
        >
          <option value="">Todo módulo</option>
          {MODULOS.map((m) => (
            <option key={m} value={m}>
              {m}
            </option>
          ))}
        </select>
        <select
          value={filtros.categoria}
          onChange={(e) => onCambio({ categoria: e.target.value })}
          aria-label="Filtrar por categoría"
          className={select}
        >
          <option value="">Toda categoría</option>
          {categorias.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
        <span className="font-mono text-sm text-overlay0" aria-live="polite">
          {total} resultado{total === 1 ? '' : 's'}
        </span>
      </div>
    </div>
  )
}
