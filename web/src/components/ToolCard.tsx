import type { Herramienta } from '@/data/types'

const COLOR_MODULO: Record<string, string> = {
  base: 'border-green/40 text-green',
  cloud: 'border-peach/40 text-peach',
  k8s: 'border-blue/40 text-blue',
  gui: 'border-pink/40 text-pink',
}

export function ToolCard({ h }: { h: Herramienta }) {
  return (
    <a
      href={h.url}
      target="_blank"
      rel="noreferrer"
      className="flex flex-col rounded-lg border border-surface0 bg-mantle p-4 transition hover:border-lavender"
    >
      <div className="flex items-start justify-between gap-3">
        <h3 className="font-mono font-semibold text-text">{h.nombre}</h3>
        <div className="flex shrink-0 gap-1">
          {h.modulos.map((m) => (
            <span
              key={m}
              className={`rounded border px-1.5 py-0.5 font-mono text-[10px] ${COLOR_MODULO[m] ?? 'border-surface1 text-overlay0'}`}
            >
              {m}
            </span>
          ))}
        </div>
      </div>
      <p className="mt-2 flex-1 text-sm leading-relaxed text-subtext0">{h.descripcion}</p>
      <p className="mt-3 font-mono text-[11px] text-overlay0">
        {h.plataformas.includes('macos') && 'macOS'}
        {h.plataformas.length === 2 && ' · '}
        {h.plataformas.includes('linux') && 'Linux'}
      </p>
    </a>
  )
}
