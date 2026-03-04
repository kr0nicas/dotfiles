# Cheat Codes - SRE Toolkit 2026

Referencia rapida de todo lo que tienes disponible. Abre con `bat ~/dotfiles/CHEAT_CODES.md`

---

## Shell (zsh)

### Navegacion

| Comando | Accion |
|---|---|
| `z proyecto` | Salta al directorio mas frecuente que coincida |
| `zi` | Selector interactivo de zoxide |
| `ls` | Listado con iconos (eza) |
| `ll` | Listado largo con info de git |
| `la` | Listado con archivos ocultos |
| `lt` | Vista de arbol (2 niveles) |
| `cat archivo` | Visualizacion con syntax highlighting (bat) |

### SSH

| Comando | Accion |
|---|---|
| `s` | Selector interactivo de hosts SSH (fzf) |
| `ssh host-name` | Conectar directo por nombre del config |

### Git (aliases en zshrc)

| Comando | Accion |
|---|---|
| `gs` | `git status -sb` |
| `ga` | `git add .` |
| `gp` | `git push` |
| `gpl` | `git pull` |
| `gl` | `git log --oneline --graph --all` |
| `gcb` | Checkout de branch con fzf |
| `dots` | Commit + push de ~/dotfiles |

### Python

| Comando | Accion |
|---|---|
| `py` | `python3` |
| `venv` | Crea virtualenv en ./venv |
| `va` | Activa el virtualenv |
| `uv pip install` | Install rapido con uv |
| `uv run script.py` | Ejecuta con dependencias auto-resueltas |

### Kubernetes (aliases)

| Comando | Accion |
|---|---|
| `k` | `kubectl` |
| `kgp` | `kubectl get pods` |
| `kgs` | `kubectl get svc` |
| `kgd` | `kubectl get deploy` |
| `kga` | `kubectl get all` |
| `kl pod` | `kubectl logs -f pod` |
| `ke pod -- sh` | `kubectl exec -it pod` |
| `kns` | `kubens` (cambiar namespace) |
| `kctx` | `kubectx` (cambiar contexto) |

### Terraform (aliases)

| Comando | Accion |
|---|---|
| `tf` | `terraform` |
| `tfi` | `terraform init` |
| `tfp` | `terraform plan` |
| `tfa` | `terraform apply` |
| `tfs` | `terraform state list` |

### Docker Compose (aliases)

| Comando | Accion |
|---|---|
| `dc` | `docker compose` |
| `dcu` | `docker compose up -d` |
| `dcd` | `docker compose down` |
| `dcl` | `docker compose logs -f` |

### Otros aliases

| Comando | Accion |
|---|---|
| `lg` | `lazygit` |
| `cheat` | Ver este archivo con bat |
| `top` | `btop` (CPU, RAM, disco, red) |
| `du` | `dust` (uso de disco visual) |
| `t` | Tmux sessionizer (selector de proyectos con fzf) |

### FZF

| Comando | Accion |
|---|---|
| `Ctrl+R` | Historial interactivo |
| `Ctrl+T` | Buscar archivos |
| `Alt+C` | cd interactivo |
| `**<Tab>` | Autocompletado fuzzy |

### direnv

| Comando | Accion |
|---|---|
| `echo 'export FOO=bar' > .envrc` | Crea config de entorno local |
| `direnv allow` | Autoriza el .envrc del directorio actual |
| (automatico) | Se carga/descarga al entrar/salir del directorio |

---

## Neovim

**Leader = Espacio**

### Archivos y Buffers

| Tecla | Accion |
|---|---|
| `Space w` | Guardar |
| `Space q` | Salir |
| `Space x` | Guardar y salir |
| `Space n` | Buffer siguiente |
| `Space p` | Buffer anterior |
| `Space d` | Cerrar buffer |

### Telescope (busqueda)

| Tecla | Accion |
|---|---|
| `Ctrl+p` | Buscar archivos |
| `Space f` | Buscar texto en proyecto (live grep) |
| `Space F` | Buscar en buffer actual |
| `Space bb` | Lista de buffers |
| `Space gc` | Historial de commits |
| `Space fh` | Buscar en help tags |

### LSP (activo al abrir archivo con server)

| Tecla | Accion |
|---|---|
| `gd` | Go to definition |
| `gr` | References |
| `K` | Hover (documentacion) |
| `Space ca` | Code action |
| `Space rn` | Rename symbol |
| `[d` / `]d` | Prev/next diagnostic |

### Git (dentro de nvim)

| Tecla | Accion |
|---|---|
| `Space gs` | Git status (fugitive) |
| `Space gb` | Git blame |
| `Space gd` | Git diff split |
| `Space gl` | Git log |
| `]h` / `[h` | Next/prev hunk (gitsigns) |
| `Space hs` | Stage hunk |
| `Space hr` | Reset hunk |
| `Space hp` | Preview hunk |

### Paneles

| Tecla | Accion |
|---|---|
| `Ctrl+h/j/k/l` | Mover entre paneles |
| `Space + Flechas` | Resize de paneles |

### File Explorer (oil.nvim)

| Tecla | Accion |
|---|---|
| `-` | Abrir explorador de archivos (directorio actual) |
| `-` (dentro de oil) | Subir un directorio |
| `Enter` | Abrir archivo/directorio |
| `q` | Cerrar |
| (editar nombres) | Renombrar/mover archivos como texto, guardar para aplicar |

### Which-Key

| Tecla | Accion |
|---|---|
| `Space` (esperar) | Muestra popup con todos los keybindings disponibles |
| `Space g` (esperar) | Muestra grupo git |
| `Space b` (esperar) | Muestra grupo buffers |
| `Space c` (esperar) | Muestra grupo code |

### Edicion

| Tecla | Accion |
|---|---|
| `Alt+j/k` | Mover linea arriba/abajo |
| `gcc` | Comentar/descomentar linea (mini.comment) |
| `gc` (visual) | Comentar seleccion |
| `sa` / `sd` / `sr` | Surround add/delete/replace (mini.surround) |
| `Space /` | Limpiar highlight de busqueda |

### Comandos utiles

| Comando | Accion |
|---|---|
| `:Lazy` | Panel de gestion de plugins |
| `:Mason` | Panel de LSP servers |
| `:LspInfo` | Ver LSP activos en buffer actual |
| `:Telescope keymaps` | Buscar todos los keymaps |

---

## Kubernetes

### kubectl

| Comando | Accion |
|---|---|
| `kubectl get pods` | Listar pods |
| `kubectl logs -f pod` | Follow logs de un pod |
| `kubectl exec -it pod -- sh` | Shell interactivo |
| `kubectl apply -f manifest.yaml` | Aplicar manifiesto |
| `kubectl get events --sort-by=.lastTimestamp` | Eventos recientes |

### k9s

| Tecla | Accion |
|---|---|
| `k9s` | Abrir TUI |
| `:pod` / `:svc` / `:deploy` | Navegar a recurso |
| `l` | Ver logs del pod |
| `s` | Shell en el container |
| `d` | Describe del recurso |
| `Ctrl+d` | Borrar recurso |
| `/` | Filtrar |
| `:xray deploy` | Vista X-ray del deployment |

### kubectx / kubens

| Comando | Accion |
|---|---|
| `kubectx` | Listar/cambiar contexto |
| `kubectx -` | Volver al contexto anterior |
| `kubens` | Listar/cambiar namespace |
| `kubens -` | Volver al namespace anterior |

### stern (logs)

| Comando | Accion |
|---|---|
| `stern app-name` | Logs de todos los pods que matchean |
| `stern app-name -n staging` | Logs en namespace especifico |
| `stern . --since 5m` | Todos los logs de los ultimos 5 min |
| `stern app -o json` | Output en JSON |

### helm

| Comando | Accion |
|---|---|
| `helm list` | Releases instalados |
| `helm install name chart/` | Instalar chart |
| `helm upgrade name chart/` | Actualizar release |
| `helm rollback name 1` | Rollback a revision |
| `helm template chart/ \| less` | Render local sin instalar |

---

## Terraform

| Comando | Accion |
|---|---|
| `terraform init` | Inicializar proyecto |
| `terraform plan -out=plan.tfplan` | Planificar cambios |
| `terraform apply plan.tfplan` | Aplicar plan |
| `terraform state list` | Listar recursos en state |
| `terraform state show recurso` | Detalle de un recurso |
| `terraform import recurso id` | Importar recurso existente |
| `terraform workspace list` | Listar workspaces |
| `terraform fmt -recursive` | Formatear todos los .tf |

---

## Docker

| Comando | Accion |
|---|---|
| `docker ps` | Containers activos |
| `docker logs -f container` | Follow logs |
| `docker exec -it container sh` | Shell en container |
| `docker build -t tag .` | Build de imagen |
| `docker compose up -d` | Levantar stack |
| `docker compose down -v` | Bajar stack + volumenes |
| `docker system prune -af` | Limpiar todo lo no usado |

---

## Cloud CLIs

### AWS

| Comando | Accion |
|---|---|
| `aws sts get-caller-identity` | Verificar quien soy |
| `aws s3 ls` | Listar buckets |
| `aws ec2 describe-instances` | Listar instancias |
| `aws logs tail /group --follow` | Tail de CloudWatch logs |
| `aws ssm start-session --target i-xxx` | SSH sin llaves via SSM |

### GCP

| Comando | Accion |
|---|---|
| `gcloud auth login` | Autenticarse |
| `gcloud config set project ID` | Cambiar proyecto |
| `gcloud compute instances list` | Listar VMs |
| `gcloud container clusters get-credentials name` | kubeconfig de GKE |
| `gcloud logging read "resource.type=k8s"` | Leer logs |

### Azure

| Comando | Accion |
|---|---|
| `az login` | Autenticarse |
| `az account set -s ID` | Cambiar suscripcion |
| `az aks get-credentials -n cluster -g rg` | kubeconfig de AKS |
| `az vm list -o table` | Listar VMs |

---

## Seguridad

### trivy

| Comando | Accion |
|---|---|
| `trivy image nginx:latest` | Scan de imagen Docker |
| `trivy fs .` | Scan de vulnerabilidades en codigo |
| `trivy config .` | Scan de IaC (Terraform, K8s manifests) |
| `trivy repo https://github.com/...` | Scan de repositorio remoto |

### sops + age

| Comando | Accion |
|---|---|
| `age-keygen -o key.txt` | Generar key pair |
| `sops --age=$(cat key.txt \| grep public) secrets.yaml` | Encriptar archivo |
| `SOPS_AGE_KEY_FILE=key.txt sops secrets.yaml` | Editar secrets encriptados |
| `sops -d secrets.yaml` | Desencriptar a stdout |

---

## Git (avanzado con delta)

| Comando | Accion |
|---|---|
| `git diff` | Diff con delta (side-by-side automatico) |
| `git log -p` | Log con patches coloreados |
| `git show HEAD` | Ultimo commit con delta |
| `lazygit` | TUI interactiva completa |

### lazygit

| Tecla | Accion |
|---|---|
| `lazygit` | Abrir |
| `Space` | Stage/unstage archivo |
| `c` | Commit |
| `P` | Push |
| `p` | Pull |
| `b` | Branches |
| `?` | Ayuda completa |

---

## Monitoreo y Diagnostico

| Comando | Accion |
|---|---|
| `btop` (o `top`) | Monitor de sistema completo (CPU, RAM, disco, red) |
| `dust` (o `du`) | Uso de disco visual por directorio |
| `dust -r` | Disco en orden inverso (mas grande primero) |
| `dust -d 2 /var` | Solo 2 niveles de profundidad |

## API y JSON

| Comando | Accion |
|---|---|
| `curlie GET url` | curl con formato httpie (colores, headers limpios) |
| `curlie POST url key=value` | POST con JSON automatico |
| `curlie -v url` | Verbose con headers formateados |
| `jless file.json` | Visor interactivo de JSON |
| `kubectl get pod -o json \| jless` | Explorar output K8s interactivamente |
| `jq '.items[].metadata.name' file.json` | Extraer campos de JSON |

## Tmux Sessionizer

| Comando | Accion |
|---|---|
| `t` | Selector fzf de proyectos en ~/projects y ~/go/src |
| (seleccionar) | Crea sesion tmux con nombre del proyecto o re-attacha |
| `tmux ls` | Listar sesiones activas |
| `tmux a -t nombre` | Re-attach a sesion existente |
| `Prefix + d` | Detach de sesion (vuelves a shell) |

## SSH (ControlMaster activo)

La primera conexion es normal. Las siguientes al mismo host son instantaneas (reutiliza socket).
Las conexiones se mantienen vivas 10 min despues de desconectar.

| Comando | Accion |
|---|---|
| `s` | Selector interactivo de hosts SSH |
| `ssh -O check host` | Verificar si hay socket activo |
| `ssh -O exit host` | Cerrar socket manualmente |

## Busqueda rapida (ripgrep + fd)

| Comando | Accion |
|---|---|
| `rg "patron"` | Buscar en todos los archivos |
| `rg "patron" -t py` | Buscar solo en Python |
| `rg "patron" -l` | Solo nombres de archivo |
| `rg "patron" --json` | Output en JSON |
| `fd "nombre"` | Buscar archivos por nombre |
| `fd -e yaml` | Buscar por extension |
| `fd -e tf -x terraform fmt` | Buscar y ejecutar comando |

---

Mantenido por Jorge Ochoa (kr0nicas) - 2026
