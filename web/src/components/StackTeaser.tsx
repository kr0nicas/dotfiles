import Link from 'next/link'
import { herramientas } from '@/data/herramientas'

export function StackTeaser() {
  const muestra = herramientas.slice(0, 24)

  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <div className="rounded-xl border border-surface0 bg-mantle p-8">
        <h2 className="text-2xl font-bold tracking-tight">
          {herramientas.length} herramientas, ninguna escrita a mano
        </h2>
        <p className="mt-3 max-w-2xl text-subtext0">
          El catálogo se deriva de los Brewfiles, de{' '}
          <code className="font-mono text-teal">lib/binaries.sh</code> y del bloque apt del
          instalador. Si el repo cambia y el catálogo no, el CI se pone rojo.
        </p>
        <div className="mt-6 flex flex-wrap gap-2">
          {muestra.map((h) => (
            <span
              key={h.id}
              className="rounded border border-surface1 px-2 py-1 font-mono text-xs text-subtext0"
            >
              {h.nombre}
            </span>
          ))}
          <span className="px-2 py-1 font-mono text-xs text-overlay0">
            +{herramientas.length - muestra.length} más
          </span>
        </div>
        <Link
          href="/stack"
          className="mt-8 inline-block rounded-md bg-lavender px-4 py-2 text-sm font-semibold text-crust transition hover:bg-teal"
        >
          Ver el catálogo completo →
        </Link>
      </div>
    </section>
  )
}
