# Changelog

Generado por `scripts/changelog.sh` desde el historial de git.
No lo edites a mano: el CI regenera y compara.

## 2026-08-08 · chore/arnes-trazabilidad

### Features

- **repo**: base del arnés de hooks con su suite de tests (`64bf677`)
- **repo**: validar el mensaje de commit en commit-msg (`cbd503b`)
- **repo**: lint de lo staged en pre-commit (`a70d7c0`)
- **repo**: barrido de secretos en pre-commit (`31cd071`)
- **repo**: guardia de main y suites en pre-push (`fd2ea1b`)
- **install**: activar los hooks del repo con phase_repo (`bda7f31`)
- **scripts**: generar CHANGELOG.md desde el historial (`a719e8c`)

### Fixes

- **docs**: cerrar el agujero de nombres con espacios en el plan (`5065f5c`)
- **docs**: exigir llaves en las comillas angulares del plan (`965aa64`)
- **docs**: anclar el chequeo de mayúscula al asunto en el plan (`9a3213f`)
- **repo**: anclar el chequeo de mayúscula al asunto del commit (`5d352b0`)
- **docs**: evitar que un comentario del plan parezca directiva de shellcheck (`f7abcde`)
- **docs**: analizar en pre-commit los scripts que no son install.sh ni lib/ (`e91dc39`)
- **repo**: analizar los scripts que no son install.sh ni lib/ (`951872d`)
- **docs**: que el stub de shellcheck registre sus argumentos (`142505d`)
- **docs**: corregir la cuenta de tests de la Task 3 en cascada (`0c41019`)
- **docs**: usar ${f##*/} en vez de basename en el barrido de secretos (`e351dd5`)
- **docs**: que el barrido de secretos falle cerrado sin grep (`9ef768e`)
- **repo**: que el barrido de secretos falle cerrado sin grep (`bc7145b`)
- **docs**: comprobar hook por hook en phase_repo en vez de chmod || true (`5e95912`)
- **install**: comprobar hook por hook en vez de chmod con || true (`bde724e`)
- **docs**: excluir del CHANGELOG los commits que solo lo tocan (`47d6258`)
- **docs**: declarar excluidos como local en emite_rango (`0315077`)
- **scripts**: excluir del CHANGELOG los commits que solo lo tocan (`afb72a3`)

### Documentación

- **repo**: spec del arnés de reglas y trazabilidad (`bee98c4`)
- **repo**: plan de implementación del arnés de trazabilidad (`bad816a`)
- **repo**: retirar assert_fails del plan, ningún task lo usa (`7d77531`)

### Tests

- **repo**: que el stub de shellcheck registre qué archivo recibe (`7324319`)

### CI

- validar mensajes y CHANGELOG en CI, y plantilla de PR (`bdfd7a1`)

## 2026-08-08 · refactor(install): partir el instalador en orquestador + lib/ por fases

- (`f70301a`)

## 2026-08-08 · docs(readme): sección gcx y postura de integridad al día

- (`636e8cb`)

## 2026-08-08 · feat(install): verificar checksums de los binarios de GitHub Releases

- (`f38c049`)

## 2026-08-08 · chore: limpiar la raíz y hacer real el fallback de vim

- (`99da500`)

## 2026-08-08 · fix(zshrc): quitar alias que rompían du/top y la ruta absoluta de opencode

- (`b3c90d0`)

## 2026-08-08 · ci: añadir workflow de lint y tests, arreglar dependabot

- (`9df95ce`)

## 2026-08-08 · docs(claude): documentar gcx, orden de carga de zshrc y convenciones de zsh

- (`858684e`)

## 2026-08-08 · fix(gcp): aplica correcciones de la revisión final de gcx

- (`de33b90`)

## 2026-08-08 · fix(zshrc): lazy-load de gsutil/bq sin ejecutar gcloud con argumentos ajenos

- (`5eab862`)

## 2026-08-08 · feat(gcp): referencia en gcx -h, aliases corregidos y cheatsheet

- (`70cbbbd`)

## 2026-08-08 · refactor(zsh): renombrar comando gcp a gcx

- (`72e7193`)

## 2026-08-08 · docs(gcp): renombrar el comando publico a gcx (colision con GNU cp de coreutils)

- (`81ae108`)

## 2026-08-08 · feat(gcp): picker de configuraciones y dispatcher gcp

- (`0299bd0`)

## 2026-08-08 · fix(gcp): escritura atómica y temporales únicos en _gcp_refresh_cache

- (`410ed87`)

## 2026-08-08 · feat(gcp): caché por cuenta y picker de proyectos

- (`da2ec52`)

## 2026-08-08 · fix(gcp): distinguir fallo de gcloud de config inexistente en gcp use

- (`6168848`)

## 2026-08-08 · feat(gcp): lectura de estado y activación de configuraciones

- (`7eaa6d3`)

## 2026-08-08 · feat(gcp): helpers de caché y filtrado con tests

- (`d048f4a`)

## 2026-08-08 · docs(gcp): extraer _gcp_config_table para no duplicar el bloque awk

- (`7e328e9`)

## 2026-08-08 · docs(gcp): spec y plan del switcher de cuentas/proyectos GCP

- (`79ec020`)

## 2026-07-25 · Update dots: 2026-07-24

- (`c2f35e7`)

## 2026-07-02 · feat(claude): add skipWorkflowUsageWarning and clean settings template

- (`12a12f9`)

## 2026-06-02 · docs(scripts): añadir README para GitHub Topics Manager

- (`cec2789`)

## 2026-06-02 · feat(scripts): añadir GitHub Topics Manager

- (`07ca80d`)

## 2026-06-02 · docs(repository): actualizar reporte - topics completados vía GitHub API

- (`189a41f`)

## 2026-06-02 · docs(repository): añadir reporte de gestión de repositorios GitHub

- (`93d825b`)

## 2026-06-02 · chore(security): add Dependabot configuration for dotfiles

- (`6c72075`)

## 2026-05-29 · chore(nvim): actualizar lazy-lock (18 plugins)

- (`8f98de7`)

## 2026-05-29 · feat(install): banner kr0nicas, menu de perfiles y deteccion de update

- (`fb2c7c5`)

## 2026-05-29 · feat(install): instalacion modular con flags --minimal/--no-{cloud,k8s,gui} (#4)

- (`edf00f3`)

## 2026-05-29 · feat: backup automatico en safe_link + docs (plataformas, FAQ, refs) (#3)

- (`b83b604`)

## 2026-05-29 · fix(install): atender items low/medium de auditoria (#2)

- (`52290ec`)

## 2026-05-29 · fix(install): cerrar hallazgos critical y high de auditoria (#1)

- (`2a8122a`)

## 2026-05-29 · docs: rediseñar README con estilo industria + agregar LICENSE MIT

- (`f000219`)

## 2026-05-29 · docs(readme): documentar wezterm, claude code, ssh colors y scripts locales

- (`fc2bc1b`)

## 2026-05-29 · feat(claude): habilitar plugins oficiales (superpowers, frontend-design, code-review)

- (`e7ee5d6`)

## 2026-05-21 · feat(claude): statusline portable + overrides locales por máquina

- (`70530e2`)

## 2026-05-21 · feat(wezterm): symlink automático en Windows/WSL2 desde install.sh

- (`1d73a3b`)

## 2026-05-21 · feat(wezterm): agregar config cross-platform Mac+WSL2

- (`fd9a5f3`)

## 2026-05-21 · feat(ssh): colores de fondo por entorno en conexiones SSH

- (`4e7dd9c`)

## 2026-05-21 · feat(claude): agregar statusline script cross-platform

- (`7e01463`)

## 2026-05-16 · fix(claude): anclar Claude Code al build nativo (fuera de fnm/npm)

- (`2fa8560`)

## 2026-05-15 · Update dots: 2026-05-15

- (`374f172`)

## 2026-05-15 · Update dots: 2026-05-15

- (`f0a072a`)

## 2026-04-23 · fix(tmux): eliminar variables de shell inválidas en tmux.conf

- (`1e5d11c`)

## 2026-04-23 · feat(zshrc): agregar aliases GCP y credential helper

- (`4f7e714`)

## 2026-04-17 · chore(nvim): actualizar lazy-lock.json

- (`e4fc65d`)

## 2026-04-17 · feat(dotfiles): modernizar stack SRE 2026

- (`421ca8c`)

## 2026-04-17 · feat(nvim): migrar treesitter a API main (master archivado)

- (`18d89c3`)

## 2026-04-17 · fix: bugs de instalación + nvim config + Brewfile cleanup

- (`ef800f4`)

## 2026-04-10 · fix: resolver conflictos y limpiar rutas hardcodeadas de Linux

- (`70df094`)

## 2026-04-10 · fix(zshrc): merge opencode PATH y OpenClaw completions

- (`3cf1553`)

## 2026-04-10 · feat(zshrc): merge linux/WSL paths y fix opencode PATH

- (`970c851`)

## 2026-04-10 · fix(nvm): evitar errores ZLE en shells no-interactivas

- (`46261e5`)

## 2026-03-10 · Update dots: 2026-03-09

- (`80a10ec`)

## 2026-03-09 · Update dots: 2026-03-09

- (`630a1c9`)

## 2026-03-09 · Update dots: 2026-03-08

- (`08244fc`)

## 2026-03-07 · Update dots: 2026-03-06

- (`7c15e16`)

## 2026-03-07 · Update dots: 2026-03-06

- (`21fb69e`)

## 2026-03-05 · Update dots: 2026-03-05

- (`c364818`)

## 2026-03-05 · Update dots: 2026-03-05

- (`9ea01da`)

## 2026-03-05 · Update dots: 2026-03-04

- (`197dff2`)

## 2026-03-04 · Update dots: 2026-03-04

- (`5359299`)

## 2026-03-04 · Update dots: 2026-03-04

- (`d366b6d`)

## 2026-03-04 · Update dots: 2026-03-04

- (`993453b`)

## 2026-03-04 · Update dots: 2026-03-04

- (`37458b0`)

## 2026-03-04 · Update dots: 2026-03-04

- (`c080058`)

## 2026-03-04 · Update dots: 2026-03-04

- (`6c3a8ee`)

## 2026-03-04 · Update dots: 2026-03-04

- (`08d74a4`)

## 2026-03-04 · Update dots: 2026-03-04

- (`28133ff`)

## 2026-03-04 · Update dots: 2026-03-04

- (`96ea4cb`)

## 2026-03-04 · Update dots: 2026-03-04

- (`5d5582f`)

## 2026-03-04 · Update dots: 2026-03-03

- (`ea6cb89`)

## 2026-03-04 · SRE: Sync dotfiles (macOS) Tue Mar  3 23:13:16 CST 2026

- (`0afdf2d`)

## 2026-03-04 · Update dots: 2026-03-03

- (`2b3e241`)

## 2026-03-04 · Migrate to Neovim + add SRE tooling for 2026

- (`9c24644`)

## 2026-03-04 · Update dots: 2026-03-03

- (`c35513c`)

## 2026-03-04 · SRE: Sync dotfiles (Linux/Ubuntu) Tue Mar  3 09:47:47 PM CST 2026

- (`2ae4940`)

## 2026-03-04 · Update dots: 2026-03-03

- (`38b3c1e`)

## 2026-03-04 · SRE: Sync dotfiles (Linux/Ubuntu) Tue Mar  3 09:35:59 PM CST 2026

- (`37762d7`)

## 2026-03-04 · SRE: Sync dotfiles (macOS) Tue Mar  3 21:34:12 CST 2026

- (`fabf554`)

## 2026-02-27 · SRE: Sync dotfiles (macOS) Fri Feb 27 07:46:58 CST 2026

- (`1279bf6`)

## 2026-02-27 · SRE: Sync dotfiles (Linux/Ubuntu) Fri Feb 27 07:43:21 AM CST 2026

- (`f207f73`)

## 2026-02-27 · SRE: Sync dotfiles (Linux/Ubuntu) Fri Feb 27 07:39:51 AM CST 2026

- (`12de2ca`)

## 2026-02-27 · SRE: Sync dotfiles (Linux/Ubuntu) Fri Feb 27 07:38:29 AM CST 2026

- (`cd341ec`)

## 2026-02-27 · SRE: Sync dotfiles (Linux/Ubuntu) Fri Feb 27 07:27:08 AM CST 2026

- (`4edcf2e`)

## 2026-02-27 · SRE: Sync dotfiles (Linux/Ubuntu) Fri Feb 27 07:25:00 AM CST 2026

- (`b3c9964`)

## 2026-02-27 · SRE: Sync dotfiles (Linux/Ubuntu) Fri Feb 27 07:23:47 AM CST 2026

- (`331b5f3`)

## 2026-02-27 · Update dots: Fri Feb 27 07:06:22 AM CST 2026

- (`df6b4d5`)

## 2026-02-27 · Update dots: Fri Feb 27 06:56:34 CST 2026

- (`35594b9`)

## 2026-02-27 · Update dots: Fri Feb 27 01:45:56 CST 2026

- (`6d4c8a7`)

## 2026-02-26 · Update dots: Thu Feb 26 17:20:32 CST 2026

- (`ad0f286`)

## 2026-02-26 · Update dots: Thu Feb 26 04:53:51 PM CST 2026

- (`42ba2ca`)

## 2026-02-26 · Update dots: Thu Feb 26 04:51:44 PM CST 2026

- (`e9e41f6`)

## 2026-02-26 · Update dots: Thu Feb 26 16:38:39 CST 2026

- (`95baaa1`)

## 2026-02-26 · Update dots: 2026-02-26

- (`0bfb045`)

## 2026-02-26 · Update dots: 2026-02-26

- (`1fd3776`)

## 2026-02-26 · Update dots: 2026-02-26

- (`f22512d`)

## 2026-02-26 · Update dots: 2026-02-26

- (`f09fb48`)

## 2026-02-26 · Update dots

- (`d1551f2`)

## 2026-02-26 · Update dots

- (`60d0132`)

## 2026-02-26 · Update dots

- (`8eb5ea6`)

## 2026-02-26 · Update dots

- (`4f375ed`)

## 2026-02-26 · Update dots: Thu Feb 26 15:32:30 CST 2026

- (`60f2436`)

## 2026-02-26 · Update dots: 2026-02-26

- (`18fda74`)

## 2026-02-26 · Update dots: 2026-02-26

- (`07e4a77`)

## 2026-02-26 · Update dots: 2026-02-26

- (`be7868d`)

## 2026-02-26 · Update dots: Thu Feb 26 15:02:28 CST 2026

- (`f750021`)

## 2026-02-26 · Update config 2026-02-26

- (`5ef64a6`)

## 2026-02-26 · Update config 2026-02-26

- (`3698c94`)

## 2026-02-26 · Update config 2026-02-26

- (`152c621`)

## 2026-02-26 · Update config 2026-02-26

- (`ee538d7`)

## 2026-02-26 · Update config 2026-02-26

- (`07d1ab5`)

## 2026-02-26 · Update config 2026-02-26

- (`37945b3`)

## 2026-02-26 · Update config 2026-02-26

- (`e317480`)

## 2026-02-26 · Update config 2026-02-26

- (`3a6defc`)

## 2026-02-26 · Upgrade to high-contrast Cyberpunk SRE palette

- (`9aebddb`)

## 2026-02-26 · Add batcat integration and FZF previewer

- (`d536115`)

## 2026-02-26 · Add batcat integration and FZF previewer

- (`39d0be2`)

## 2026-02-26 · Fix Starship palette syntax and clean config

- (`dff8d44`)

## 2026-02-26 · Fix Starship palette syntax and clean config

- (`5390bf6`)

## 2026-02-26 · Fix starship palette syntax and zoxide path

- (`cac2742`)

## 2026-02-26 · Add git configuration to dotfiles

- (`bd8576b`)

## 2026-02-26 · Add Python productivity aliases and custom Starship config

- (`8857874`)

## 2026-02-26 · Initial terminal setup: Zsh + Starship

- (`f7e1346`)
