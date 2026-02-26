\# 🚀 Jorge's Dotfiles (Zsh + Starship + Python/Go)

Configuración de terminal ultra-rápida optimizada para **Ubuntu (VPS)** y **macOS**.

## 🛠 Instalación en un equipo nuevo
```bash
git clone [https://github.com/TU_USUARIO/dotfiles.git](https://github.com/TU_USUARIO/dotfiles.git) ~/dotfiles
cd ~/dotfiles && ./install.sh
```
---

##⚡️ Atajos de Productividad (Cheat Sheet)
📂 Navegación Inteligente (zoxide & eza)ComandoAcciónz [carpeta]Salto inteligente a carpetas frecuentes (reemplaza cd)lsListado con iconos y carpetas primerollListado largo con detalles de Git y permisoslaListado total (incluye archivos ocultos)ltVer estructura de carpetas en modo árbol

#🐍 Python & Desarrollo
ComandoAcciónpyEjecuta python3venvCrea un entorno virtual rápido (python3 -m venv venv)vaActiva el entorno virtual (source venv/bin/activate)pipirInstala dependencias desde requirements.txt

#🔍 Búsqueda y Visualización (fzf & bat)
ComandoAccióncat [file]Ver archivo con colores y números de línea (batcat)fpFuzzy Preview: Busca archivos y previsualízalos antes de abrirCtrl + RBúsqueda interactiva en el historial de comandosgcbSelector visual de ramas de Git para cambiar (checkout)

#🐳 Docker & Infra
ComandoAccióndpsTabla limpia de contenedores activosdcu / dcddocker-compose up -d / downto-edwinCambiar al usuario de servicios edwin

#💾 Gestión de Configuración
source ~/.zshrc: Recarga la configuración actual.dots: Sincroniza automáticamente todos tus cambios a GitHub.Mantenido por Jorge Ochoa - 2026


### 3. El toque final: Un alias para leer tu propia guía
Para que esta hoja de trucos sea realmente útil, añade este alias a tu `~/dotfiles/.zshrc`:


# Leer mi hoja de trucos al instante
alias help-me='batcat ~/dotfiles/README.md --paging=never'
