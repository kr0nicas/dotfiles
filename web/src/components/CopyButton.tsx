'use client'

import { useState } from 'react'

export function CopyButton({ texto }: { texto: string }) {
  const [copiado, setCopiado] = useState(false)

  async function copiar() {
    try {
      await navigator.clipboard.writeText(texto)
      setCopiado(true)
      setTimeout(() => setCopiado(false), 2000)
    } catch {
      // Sin permiso de portapapeles no hay nada que hacer: el comando está
      // visible y se puede seleccionar a mano.
    }
  }

  return (
    <button
      onClick={copiar}
      aria-label={copiado ? 'Comando copiado' : 'Copiar comando'}
      className="rounded-md border border-surface1 px-3 py-1.5 font-mono text-xs text-subtext0 transition hover:border-lavender hover:text-lavender"
    >
      {copiado ? '✓ copiado' : 'copiar'}
    </button>
  )
}
