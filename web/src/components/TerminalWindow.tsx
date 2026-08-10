export function TerminalWindow({
  titulo,
  children,
}: {
  titulo?: string
  children: React.ReactNode
}) {
  return (
    <div className="overflow-hidden rounded-lg border border-surface0 bg-crust shadow-2xl shadow-black/40">
      <div className="flex items-center gap-2 border-b border-surface0 bg-surface0/60 px-4 py-2.5">
        <span className="size-3 rounded-full bg-red" />
        <span className="size-3 rounded-full bg-yellow" />
        <span className="size-3 rounded-full bg-green" />
        {titulo && <span className="ml-2 font-mono text-xs text-overlay0">{titulo}</span>}
      </div>
      <div className="p-5 font-mono text-sm leading-relaxed">{children}</div>
    </div>
  )
}
