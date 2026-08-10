import { Suspense } from 'react'
import { Catalogo } from '@/components/Catalogo'

export const metadata = {
  title: 'El stack completo — Dotfiles SRE 2026',
  description: 'Catálogo filtrable de todas las herramientas que instala el repo.',
}

export default function StackPage() {
  return (
    // useSearchParams obliga a este Suspense. Sin él, `next build` falla — y
    // `next dev` no, que es la peor forma de descubrirlo.
    <Suspense fallback={<div className="mx-auto max-w-6xl px-6 py-16">Cargando…</div>}>
      <Catalogo />
    </Suspense>
  )
}
