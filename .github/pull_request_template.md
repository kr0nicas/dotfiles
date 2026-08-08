## Qué cambia

<!-- Una o dos frases. El diff ya dice el detalle. -->

## Por qué

<!-- El problema real, no la solución. Si hay spec, enlázalo:
     docs/superpowers/specs/YYYY-MM-DD-<tema>-design.md -->

## Cómo se verificó

<!-- Comandos y salida real. "Probado" no es una verificación. -->

```
$ 
```

## Checklist

- [ ] Los mensajes de commit siguen la convención (`.githooks/commit-msg` los validó)
- [ ] `bash .githooks/hooks.test.sh` pasa
- [ ] `zsh config/zsh/gcp.test.zsh` pasa si se tocó `config/zsh/`
- [ ] `shellcheck -x -S warning install.sh` pasa si se tocó `install.sh` o `lib/`
- [ ] `./install.sh --dry-run` comparado antes/después si se tocó el instalador
- [ ] `./scripts/changelog.sh` regenerado como último paso antes del push
- [ ] `CLAUDE.md` actualizado si cambió una convención
