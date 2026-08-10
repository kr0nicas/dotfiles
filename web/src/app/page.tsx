import { Hero } from '@/components/Hero'
import { Highlights } from '@/components/Highlights'
import { PresetSelector } from '@/components/PresetSelector'
import { Capturas } from '@/components/Capturas'
import { Gcx } from '@/components/Gcx'
import { StackTeaser } from '@/components/StackTeaser'
import { Footer } from '@/components/Footer'
import { cuentaDePreset, herramientas, presets } from '@/data/herramientas'

// Los recuentos se hacen aquí, en servidor, y viajan como props. Si los
// calcularan los propios componentes de cliente, el catálogo entero acabaría en
// el bundle del navegador solo para imprimir unas cifras.
const FORMULAS = herramientas.filter((h) => h.entradas.some((e) => e.tipo === 'brew')).length

const PRESETS = presets.map((p) => ({ ...p, cuenta: cuentaDePreset(p) }))

export default function Home() {
  return (
    <>
      <main>
        <Hero formulas={FORMULAS} />
        <Highlights />
        <PresetSelector presets={PRESETS} />
        <Capturas />
        <Gcx />
        <StackTeaser />
      </main>
      <Footer />
    </>
  )
}
