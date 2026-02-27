🚀 Guía Maestra de Vim para SRE (Jorge Ochoa)

Esta guía explica cómo aprovechar las modificaciones de tu vimrc para ser más productivo en la gestión de servidores y código de OpenClaw.

1. El Secreto del Movimiento: Números Relativos

Hemos configurado set relativenumber. Esto es vital para un SRE:

¿Cómo funciona?: La línea actual muestra su número real, pero las de arriba y abajo muestran la distancia (1, 2, 3...).

Caso de uso: Si ves que un error en un log está 12 líneas más abajo, simplemente escribe 12j y saltarás exactamente ahí. No tienes que calcular nada.

2. La Tecla Líder (Leader Key)

Tu tecla líder es el Espacio. Es la más fácil de presionar y no interfiere con otros comandos.

Atajo

Acción

Descripción

Espacio + w

Guardar

Equivale a :w

Espacio + q

Salir

Equivale a :q

Espacio + x

Guardar y Salir

Equivale a :x

3. Multitarea: Paneles y Buffers

Como SRE, a menudo necesitas ver un log y un archivo de configuración al mismo tiempo.

División de Paneles (Splits)

Usa los comandos de siempre para dividir (:vsp para vertical, :sp para horizontal), pero muévete entre ellos como un pro:

Ctrl + h: Mover al panel de la izquierda.

Ctrl + j: Mover al panel de abajo.

Ctrl + k: Mover al panel de arriba.

Ctrl + l: Mover al panel de la derecha.

Gestión de Buffers (Archivos Abiertos)

Si abres varios archivos (vim file1.txt file2.yaml), usa estos atajos:

Espacio + n: Siguiente archivo (next).

Espacio + p: Archivo anterior (previous).

Espacio + d: Cerrar el archivo actual (delete buffer).

4. Búsqueda con FZF (Integración 0.66.0)

Aprovechando que instalamos la última versión de fzf, ahora puedes buscar archivos sin salir de Vim:

Ctrl + p: Abre el buscador de archivos en el directorio actual.

Espacio + f: Busca texto específico dentro de todas las líneas de los archivos que tienes abiertos.

5. Inteligencia por Lenguaje

Vim ahora sabe qué estás editando y ajusta las reglas de Partnertech:

YAML (Kubernetes/OpenClaw): Al presionar Tab, Vim pondrá 2 espacios automáticamente. Esto evita errores de indentación en K8s.

Go: Usará Tabs reales de 4 espacios (estándar de Google).

Limpieza Automática: Al guardar cualquier archivo, Vim eliminará los espacios en blanco sobrantes al final de las líneas para mantener el repositorio limpio.

💡 Tips Rápidos de Supervivencia

Modo Mouse: Puedes hacer clic en una línea para mover el cursor o usar la rueda para hacer scroll gracias a set mouse=a.

Portapapeles: Al copiar algo en Vim con y (yank), se irá al portapapeles de tu Mac/Linux si el sistema lo soporta.

Búsqueda: Al buscar con /, Vim ignorará mayúsculas a menos que escribas una letra mayúscula a propósito (smartcase).
