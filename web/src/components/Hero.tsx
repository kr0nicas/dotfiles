'use client'

import { useEffect, useState } from 'react'
import { CopyButton } from './CopyButton'
import { TerminalWindow } from './TerminalWindow'

const COMANDO = 'git clone https://github.com/kr0nicas/dotfiles ~/dotfiles && ~/dotfiles/install.sh'

// `formulas` llega como prop desde page.tsx, que es un componente de servidor.
// Sigue saliendo del catálogo y no de una constante tecleada —la regla de gcx
// vale igual aquí—, pero el recuento se hace al construir. Importar el catálogo
// desde este fichero lo metía entero en el bundle del navegador: 68 KB de JSON
// embarcados para imprimir un número. La línea de symlinks no lleva cifra por
// otro motivo: el número de enlaces no sale de ninguna fuente legible desde aquí.
export function Hero({ formulas }: { formulas: number }) {
  const [escrito, setEscrito] = useState('')
  const [listo, setListo] = useState(false)

  const salida = [
    { texto: '✔ detect · macOS arm64', color: 'text-green' },
    { texto: `✔ packages · ${formulas} fórmulas`, color: 'text-green' },
    { texto: '✔ binaries · sha256 verificados', color: 'text-green' },
    { texto: '✔ symlinks · configs enlazadas', color: 'text-green' },
  ]

  useEffect(() => {
    const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches
    if (reduce) {
      setEscrito(COMANDO)
      setListo(true)
      return
    }
    let i = 0
    const id = setInterval(() => {
      i += 1
      setEscrito(COMANDO.slice(0, i))
      if (i >= COMANDO.length) {
        clearInterval(id)
        setListo(true)
      }
    }, 22)
    return () => clearInterval(id)
  }, [])

  return (
    <section className="mx-auto max-w-5xl px-6 pt-24 pb-20 sm:pt-32">
      <p className="font-mono text-xs uppercase tracking-[0.2em] text-overlay0">
        SRE 2026 · macOS + Debian
      </p>
      <h1 className="mt-5 text-5xl font-bold leading-[1.05] tracking-tight sm:text-6xl">
        Toda la caja,
        <br />
        <span className="text-teal">un comando</span>
      </h1>
      <p className="mt-6 max-w-xl text-lg text-subtext0">
        Terminal, editor, cloud y Kubernetes reproducibles en cualquier máquina. Cinco presets,
        dos sistemas operativos y checksums verificados en cada binario.
      </p>

      <div className="mt-10">
        <TerminalWindow titulo="~/dotfiles">
          <p className="break-all text-text">
            <span className="text-teal">❯ </span>
            {escrito}
            {!listo && <span className="ml-0.5 inline-block w-2 animate-pulse bg-text">&nbsp;</span>}
          </p>
          {listo &&
            salida.map((l) => (
              <p key={l.texto} className={`mt-1 ${l.color}`}>
                {l.texto}
              </p>
            ))}
        </TerminalWindow>
      </div>

      <div className="mt-6 flex flex-wrap items-center gap-3">
        <CopyButton texto={COMANDO} />
        <a
          href="#presets"
          className="rounded-md bg-lavender px-4 py-1.5 text-sm font-semibold text-crust transition hover:bg-teal"
        >
          Ver los presets
        </a>
        <a
          href="https://github.com/kr0nicas/dotfiles"
          className="rounded-md border border-surface1 px-4 py-1.5 text-sm text-subtext0 transition hover:border-lavender hover:text-lavender"
        >
          Repo en GitHub
        </a>
      </div>
    </section>
  )
}
