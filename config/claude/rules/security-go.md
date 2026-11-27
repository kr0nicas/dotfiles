---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---
# Seguridad en Go

- Secretos solo desde el entorno; `log.Fatal` si falta la variable.
- SAST antes de commit: `gosec ./...`.
- Vulnerabilidades en dependencias: `go run golang.org/x/vuln/cmd/govulncheck@latest ./...`.
- `context.WithTimeout` en toda llamada de red o base de datos.
- `database/sql` con placeholders; nunca `fmt.Sprintf` en SQL.
- `os/exec` con argumentos separados, nunca `sh -c` con entrada externa.
