'use client'

import { useState } from 'react'
import type { PresetConCuenta } from '@/data/types'
import { SectionHeading } from './SectionHeading'
import { TerminalWindow } from './TerminalWindow'

const DESCRIPCION: Record<string, string> = {
  '--minimal': 'Solo el entorno de terminal. Sin cloud, sin Kubernetes, sin apps de escritorio.',
  '--vps': 'Servidor con trabajo de cloud: base más las CLIs de AWS, Azure, GCP y OpenTofu.',
  '--container': 'Imagen de Docker. Ultra-mínimo: lo justo para que la shell sea usable.',
  '--k8s-node': 'Nodo de Kubernetes: base, cloud y todo el instrumental de clúster.',
  '--agent':
    'Caja de agente. Salta los editores y solo enlaza ~/.claude, porque una zsh no interactiva nunca lee el resto.',
}

const MODULOS = [
  { clave: 'cloud', etiqueta: 'cloud' },
  { clave: 'k8s', etiqueta: 'k8s' },
  { clave: 'gui', etiqueta: 'gui' },
] as const

export function PresetSelector({ presets }: { presets: PresetConCuenta[] }) {
  const [activo, setActivo] = useState(presets[0]?.flag ?? '')
  const preset = presets.find((p) => p.flag === activo) ?? presets[0]

  if (!preset) return null

  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="presets" eyebrow="Presets" titulo="Una caja, cinco formas">
        Los presets no eligen herramientas sueltas: encienden módulos. El recuento sale del
        catálogo, así que no puede desfasarse del instalador.
      </SectionHeading>

      <div className="flex flex-wrap gap-2" role="tablist" aria-label="Presets disponibles">
        {presets.map((p) => (
          <button
            key={p.flag}
            role="tab"
            aria-selected={p.flag === activo}
            onClick={() => setActivo(p.flag)}
            className={`rounded-md border px-3 py-1.5 font-mono text-sm transition ${
              p.flag === activo
                ? 'border-lavender bg-lavender/10 text-lavender'
                : 'border-surface0 text-subtext0 hover:border-surface1 hover:text-text'
            }`}
          >
            {p.flag}
          </button>
        ))}
      </div>

      <div className="mt-6 grid gap-6 lg:grid-cols-2">
        <TerminalWindow titulo="instalación">
          <p>
            <span className="text-teal">❯ </span>
            <span className="text-text">./install.sh {preset.flag}</span>
          </p>
          <p className="mt-3 text-subtext0">
            módulos: <span className="text-green">base=ON</span>
            {MODULOS.map((m) => (
              <span key={m.clave}>
                {', '}
                <span className={preset[m.clave] ? 'text-green' : 'text-overlay0'}>
                  {m.etiqueta}={preset[m.clave] ? 'ON' : 'OFF'}
                </span>
              </span>
            ))}
          </p>
          <p className="mt-3 text-peach">≈ {preset.cuenta} herramientas</p>
        </TerminalWindow>

        <div className="rounded-lg border border-surface0 bg-mantle p-6">
          <h3 className="font-mono text-lg text-lavender">{preset.flag}</h3>
          <p className="mt-3 leading-relaxed text-subtext0">
            {DESCRIPCION[preset.flag] ?? 'Preset del instalador.'}
          </p>
        </div>
      </div>
    </section>
  )
}
