export function SectionHeading({
  id,
  eyebrow,
  titulo,
  children,
}: {
  id: string
  eyebrow: string
  titulo: string
  children?: React.ReactNode
}) {
  return (
    <div className="mb-10 scroll-mt-24" id={id}>
      <p className="font-mono text-xs uppercase tracking-[0.2em] text-overlay0">{eyebrow}</p>
      <h2 className="mt-3 text-3xl font-bold tracking-tight text-text sm:text-4xl">{titulo}</h2>
      {children && <p className="mt-4 max-w-2xl text-subtext0">{children}</p>}
    </div>
  )
}
