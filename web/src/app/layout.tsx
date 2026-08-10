import type { Metadata } from 'next'
import { herramientas, presets } from '@/data/herramientas'
import './globals.css'

// Las dos cifras salen del catálogo. Tecleadas a mano envejecen al primer brew
// nuevo o al primer preset, y una descripción en el <head> es justo el sitio
// donde nadie va a mirar para corregirla.
//
// «checksums verificados en cada binario» y no «... en cada herramienta»: solo
// lo que baja de GitHub Releases se comprueba contra un sha256, no las 134.
export const metadata: Metadata = {
  title: 'Dotfiles SRE 2026 — Jorge Ochoa',
  description: `Entorno SRE reproducible para macOS y Debian: un comando, ${presets.length} presets, ${herramientas.length} herramientas y checksums verificados en cada binario.`,
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className="bg-base text-text antialiased">{children}</body>
    </html>
  )
}
