'use client'

import { useRouter, useSearchParams } from 'next/navigation'
import { useMemo } from 'react'
import { herramientas, categorias } from '@/data/herramientas'
import { FilterBar, comoModulo, comoPlataforma, type Filtros } from './FilterBar'
import { ToolCard } from './ToolCard'

function normalizar(s: string) {
  return s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
}

export function Catalogo() {
  const router = useRouter()
  const params = useSearchParams()

  const filtros: Filtros = {
    q: params.get('q') ?? '',
    modulo: comoModulo(params.get('m') ?? ''),
    plataforma: comoPlataforma(params.get('p') ?? ''),
    categoria: params.get('c') ?? '',
  }

  function onCambio(parcial: Partial<Filtros>) {
    const siguiente = { ...filtros, ...parcial }
    const qs = new URLSearchParams()
    if (siguiente.q) qs.set('q', siguiente.q)
    if (siguiente.modulo) qs.set('m', siguiente.modulo)
    if (siguiente.plataforma) qs.set('p', siguiente.plataforma)
    if (siguiente.categoria) qs.set('c', siguiente.categoria)
    const cadena = qs.toString()
    router.replace(cadena ? `?${cadena}` : '/stack', { scroll: false })
  }

  const visibles = useMemo(() => {
    const q = normalizar(filtros.q)
    return herramientas.filter((h) => {
      if (filtros.modulo && !h.modulos.includes(filtros.modulo)) return false
      if (filtros.plataforma && !h.plataformas.includes(filtros.plataforma)) return false
      if (filtros.categoria && h.categoria !== filtros.categoria) return false
      if (!q) return true
      return normalizar(`${h.nombre} ${h.descripcion} ${h.categoria}`).includes(q)
    })
  }, [filtros.q, filtros.modulo, filtros.plataforma, filtros.categoria])

  return (
    <div className="mx-auto max-w-6xl px-6 py-16">
      <p className="font-mono text-xs uppercase tracking-[0.2em] text-overlay0">Catálogo</p>
      <h1 className="mt-3 text-4xl font-bold tracking-tight">El stack completo</h1>
      <p className="mt-4 max-w-2xl text-subtext0">
        Todo lo que instala el repo, derivado de los Brewfiles, de{' '}
        <code className="font-mono text-teal">lib/binaries.sh</code> y del bloque apt. Ni un
        nombre está escrito a mano.
      </p>

      <div className="mt-10">
        <FilterBar
          filtros={filtros}
          categorias={categorias}
          onCambio={onCambio}
          total={visibles.length}
        />

        {visibles.length === 0 ? (
          <p className="py-16 text-center font-mono text-subtext0">
            Nada coincide con esos filtros.
          </p>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {visibles.map((h) => (
              <ToolCard key={h.id} h={h} />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
