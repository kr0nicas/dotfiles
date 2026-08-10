export type Modulo = 'base' | 'cloud' | 'k8s' | 'gui'
export type Plataforma = 'macos' | 'linux'
export type TipoEntrada = 'brew' | 'cask' | 'vscode' | 'apt' | 'github'

/** Lo que el repo declara. Generado, nunca escrito a mano. */
export interface Entrada {
  clave: string
  nombre: string
  tipo: TipoEntrada
  modulo: Modulo
  plataforma: Plataforma
  fuente: string
  repo?: string
  categoriaBrewfile?: string
}

/** Lo que una máquina no puede saber. Escrito a mano. */
export interface Curada {
  id: string
  nombre: string
  categoria: string
  descripcion: string
  url: string
  /** Claves de `Entrada` que esta ficha cubre, p.ej. ['brew:fd', 'apt:fd-find']. */
  declarado: string[]
}

export interface Preset {
  flag: string
  cloud: boolean
  k8s: boolean
  gui: boolean
}

/**
 * Un preset con sus recuentos ya calculados. Existe para que el servidor cuente
 * y el cliente solo pinte: `cuentaDePreset` recorre el catálogo entero, así que
 * llamarla desde un componente de cliente embarcaría el JSON en el navegador.
 */
export interface PresetConCuenta extends Preset {
  cuenta: { macos: number; linux: number }
}

export interface Generado {
  entradas: Entrada[]
  presets: Preset[]
  conteos: Record<string, number>
}

/** Lo que consume la UI: una ficha curada + de dónde sale realmente. */
export interface Herramienta extends Omit<Curada, 'declarado'> {
  modulos: Modulo[]
  plataformas: Plataforma[]
  entradas: Entrada[]
}
