import { SectionHeading } from './SectionHeading'
import { TerminalWindow } from './TerminalWindow'

export function Gcx() {
  return (
    <section className="mx-auto max-w-5xl px-6 py-20">
      <SectionHeading id="gcx" eyebrow="Pieza propia" titulo="gcx — saltar de cuenta en GCP">
        Sustituyó a cuatro aliases que imprimían con{' '}
        <code className="font-mono text-teal">echo</code> una cuenta escrita a mano que ya no
        coincidía con la configuración que activaban. Ahora cada dato se lee de{' '}
        <code className="font-mono text-teal">gcloud</code> en el momento.
      </SectionHeading>

      <div className="grid gap-6 lg:grid-cols-2">
        <TerminalWindow titulo="gcx">
          <p>
            <span className="text-teal">❯ </span>
            <span className="text-text">gcx</span>
          </p>
          <p className="mt-2 text-subtext0">{'>'} personal   ochoa.j@gmail.com   mi-proyecto</p>
          <p className="text-overlay0">  trabajo    j.ochoa@empresa    prod-eu</p>
          <p className="text-overlay0">  cliente    sre@cliente.io     staging</p>
          <p className="mt-3">
            <span className="text-teal">❯ </span>
            <span className="text-text">gcx p</span>
            <span className="text-overlay0"> · proyectos de la cuenta activa (con caché)</span>
          </p>
        </TerminalWindow>

        <div className="space-y-3">
          {[
            ['gcx', 'Picker de configuraciones: cuenta y proyecto'],
            ['gcx p [-r]', 'Proyectos de la cuenta activa; -r refresca la caché'],
            ['gcx use <config>', 'Activa una configuración por nombre'],
            ['gcx who', 'Config, cuenta y proyecto activos'],
          ].map(([cmd, desc]) => (
            <div key={cmd} className="rounded-lg border border-surface0 bg-mantle p-4">
              <code className="font-mono text-sm text-lavender">{cmd}</code>
              <p className="mt-1 text-sm text-subtext0">{desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
