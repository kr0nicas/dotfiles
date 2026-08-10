const ENLACES = [
  ['Repositorio', 'https://github.com/kr0nicas/dotfiles'],
  ['CHANGELOG', 'https://github.com/kr0nicas/dotfiles/blob/main/CHANGELOG.md'],
  ['Chuleta', 'https://github.com/kr0nicas/dotfiles/blob/main/CHEAT_CODES.md'],
  ['Diseños y planes', 'https://github.com/kr0nicas/dotfiles/tree/main/docs'],
]

export function Footer() {
  return (
    <footer className="border-t border-surface0 bg-mantle">
      <div className="mx-auto flex max-w-5xl flex-wrap items-center justify-between gap-4 px-6 py-10">
        <p className="font-mono text-sm text-overlay0">dotfiles · Jorge Ochoa (kr0nicas) · MIT</p>
        <nav className="flex flex-wrap gap-4">
          {ENLACES.map(([texto, href]) => (
            <a
              key={href}
              href={href}
              className="text-sm text-subtext0 transition hover:text-lavender"
            >
              {texto}
            </a>
          ))}
        </nav>
      </div>
    </footer>
  )
}
