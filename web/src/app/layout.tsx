import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Dotfiles SRE 2026 — Jorge Ochoa',
  description:
    'Entorno SRE reproducible para macOS y Debian: un comando, cinco presets, más de 130 herramientas con checksums verificados.',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es">
      <body className="bg-base text-text antialiased">{children}</body>
    </html>
  )
}
