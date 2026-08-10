'use client'

import { useState } from 'react'
import { SectionHeading } from './SectionHeading'
import { TerminalWindow } from './TerminalWindow'

const CAPTURAS = [
  { archivo: 'nvim.png', titulo: 'nvim', pie: 'Neovim con LSP, telescope y Catppuccin' },
  { archivo: 'tmux.png', titulo: 'tmux', pie: 'Prefijo en C-a, navegación compartida con nvim' },
  { archivo: 'starship.png', titulo: 'starship', pie: 'Prompt con estado de git, cloud y k8s' },
  { archivo: 'k9s.png', titulo: 'k9s', pie: 'El clúster sin escribir kubectl' },
  { archivo: 'gcx.png', titulo: 'gcx', pie: 'Cambiar de cuenta y proyecto de GCP con fzf' },
]

function Captura({ archivo, titulo, pie }: { archivo: string; titulo: string; pie: string }) {
  const [falla, setFalla] = useState(false)

  return (
    <figure>
      <TerminalWindow titulo={titulo}>
        {falla ? (
          <div className="flex h-48 items-center justify-center rounded border border-dashed border-surface1 text-center text-xs text-overlay0">
            Falta <code className="mx-1 text-peach">public/screenshots/{archivo}</code>
          </div>
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={`/dotfiles/screenshots/${archivo}`}
            alt={pie}
            width={1600}
            height={1000}
            className="w-full rounded"
            onError={() => setFalla(true)}
          />
        )}
      </TerminalWindow>
      <figcaption className="mt-3 text-sm text-subtext0">{pie}</figcaption>
    </figure>
  )
}

export function Capturas() {
  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="capturas" eyebrow="El entorno" titulo="Así se ve" />
      <div className="grid gap-8 lg:grid-cols-2">
        {CAPTURAS.map((c) => (
          <Captura key={c.archivo} {...c} />
        ))}
      </div>
    </section>
  )
}
