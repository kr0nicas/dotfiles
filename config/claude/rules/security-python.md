---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
---
# Seguridad en Python

- Secretos solo desde el entorno: `os.environ["X"]` (falla si falta), nunca literales.
- SAST antes de commit: `uvx bandit -r src/`.
- Dependencias: `uvx pip-audit`. Fijar versiones en `pyproject.toml` y lockfile de `uv`.
- Sin `pickle.loads`, `eval`, `exec` ni `shell=True` sobre datos externos.
- Validar entrada con `pydantic` en la frontera; no confiar en tipos del cliente.
