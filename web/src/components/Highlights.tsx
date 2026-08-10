import { SectionHeading } from './SectionHeading'

const PUNTOS = [
  {
    titulo: 'Cross-platform de verdad',
    texto:
      'macOS con Homebrew y Debian con apt más binarios de GitHub Releases. No es un dotfiles de Mac con un if suelto.',
    acento: 'text-blue',
  },
  {
    titulo: 'Cinco presets',
    texto:
      'VPS, contenedor, nodo de Kubernetes, caja de agente y mínimo. Cada uno enciende los módulos que esa máquina va a usar.',
    acento: 'text-mauve',
  },
  {
    titulo: 'Checksums verificados',
    texto:
      'Cada binario que baja de GitHub Releases se comprueba contra el sha256 del propio release, y avisa cuando el proyecto no publica ninguno.',
    acento: 'text-green',
  },
  {
    titulo: 'Arnés de reglas',
    texto:
      'Hooks de git y CI que validan sintaxis, shellcheck a nivel info, convención de commits y el CHANGELOG generado.',
    acento: 'text-peach',
  },
  {
    titulo: 'Catppuccin Mocha en todo',
    texto:
      'Neovim, tmux, starship, delta y esta misma página comparten paleta. Cambiar de máquina no cambia de entorno.',
    acento: 'text-pink',
  },
]

export function Highlights() {
  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="highlights" eyebrow="Por qué" titulo="Qué lo hace distinto" />
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {PUNTOS.map((p) => (
          <div
            key={p.titulo}
            className="rounded-lg border border-surface0 bg-mantle p-5 transition hover:border-surface1"
          >
            <h3 className={`font-semibold ${p.acento}`}>{p.titulo}</h3>
            <p className="mt-2 text-sm leading-relaxed text-subtext0">{p.texto}</p>
          </div>
        ))}
      </div>
    </section>
  )
}
