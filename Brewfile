# ==============================================================================
# Brewfile (base) - Jorge Ochoa (kr0nicas)
# Stack mínimo: terminal env + nvim + linters + lenguajes + security + fonts.
# Brewfiles modulares: Brewfile.cloud, Brewfile.k8s, Brewfile.gui
# (instalados condicionalmente por install.sh segun flags --no-{cloud,k8s,gui}).
# ==============================================================================

# --- Core CLI ---
brew "git"
brew "zsh"
brew "zsh-completions"
brew "zsh-autosuggestions"
brew "zsh-syntax-highlighting"
brew "curl"
brew "wget"
brew "tree"
brew "tmux"
brew "neovim"
brew "gh"
brew "glab"
brew "tldr"

# --- Modern CLI (Rust-powered) ---
brew "bat"
brew "eza"
brew "fzf"
brew "ripgrep"
brew "fd"
brew "zoxide"
brew "starship"
brew "delta"
brew "sd"
brew "lazygit"
brew "git-extras"
brew "direnv"
brew "jq"
brew "python-yq"
brew "dust"
brew "btop"
brew "curlie"
brew "jless"

# --- Red y diagnóstico ---
# mtr, nmap y trippy abren raw sockets: en macOS piden sudo la primera vez.
# termshark arrastra wireshark como dependencia de fórmula (necesita `tshark`
# para capturar); no hace falta declararlo aparte.
brew "mtr"
brew "trippy"          # binario `trip`, no `trippy`
brew "nmap"
brew "socat"
brew "step"            # step certificate inspect — TLS legible
brew "iperf3"
brew "bandwhich"
brew "termshark"
brew "oha"
brew "doggo"
brew "sshuttle"
brew "lnav"

# --- Linters & formatters (nvim: nvim-lint + conform.nvim) ---
brew "tree-sitter-cli"
brew "shellcheck"
brew "yamllint"
brew "stylua"
brew "ruff"
brew "pre-commit"
# golangci-lint no lo declara nvim-lint (que para Go no configura nada): es el
# linter de línea de comandos y de CI. Va aquí y no en la sección Go de abajo
# porque esa usa `go "..."`, que compila desde fuente en cada máquina.
brew "golangci-lint"

# --- Security ---
brew "trivy"
brew "pass"
brew "pinentry-mac"
brew "sops"
brew "age"
brew "gitleaks"       # escáner de secretos; base y no .cloud: escanea cualquier repo git

# --- Languages ---
brew "go"
brew "uv"
brew "fnm"
brew "openjdk@17"
brew "gradle"
brew "maven"
brew "jenv"

# --- Misc ---
# libfaketime: `faketime '2026-01-01' <cmd>` miente la fecha a un proceso sin
# tocar el reloj del sistema. Es tooling de este repo: el arnés de CHANGELOG y
# los hooks agrupan por fecha, y probar esos caminos sin falsear el reloj
# obliga a esperar a mañana. En Debian el paquete se llama `faketime`.
brew "libfaketime"
brew "openssl@3"
brew "telnet"
brew "nghttp2"
brew "llm"
brew "gemini-cli"

# --- Terminal casks (siempre necesarios) ---
cask "font-hack-nerd-font"
cask "font-source-code-pro"
cask "iterm2"
cask "wezterm"

# --- Go tools (LSP + sec audit) ---
go "golang.org/x/tools/gopls"
go "github.com/securego/gosec/v2/cmd/gosec"
