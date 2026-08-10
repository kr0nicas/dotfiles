import { Hero } from '@/components/Hero'
import { herramientas } from '@/data/herramientas'

// El recuento se hace aquí, en servidor, y viaja como prop. Si lo calculara el
// propio Hero —que es un componente de cliente— el catálogo entero acabaría en
// el bundle del navegador solo para imprimir una cifra.
const FORMULAS = herramientas.filter((h) => h.entradas.some((e) => e.tipo === 'brew')).length

export default function Home() {
  return (
    <main>
      <Hero formulas={FORMULAS} />
    </main>
  )
}
