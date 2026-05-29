# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo purpose

Cross-platform dotfiles for Jorge Ochoa (kr0nicas) — SRE 2026 setup targeting **macOS** (Apple Silicon/Intel) and **Debian/Ubuntu** (VPS, GCP, AWS). A single `./install.sh` bootstraps the full environment.

## Installation & common commands

```bash
./install.sh              # Full install (macOS via Brewfile + brew bundle; Linux via apt + binary downloads)
./install.sh --dry-run    # Simulate without making changes
./install.sh --minimal    # Skip cloud, k8s, GUI (only base terminal env)
./install.sh --no-cloud   # Skip aws/azure/terraform/vault/gcloud
./install.sh --no-k8s     # Skip kubectl/helm/k9s/stern/kubectx/docker
./install.sh --no-gui     # Skip VSCode + extensions + Brave/Spotify/Postman
./install.sh --help       # Show all options

brew bundle --file=~/dotfiles/Brewfile   # Install/sync base macOS packages (cloud/k8s/gui in Brewfile.{cloud,k8s,gui})
source ~/.zshrc                          # Reload shell after config changes
```

Post-install:
```bash
nvim                    # lazy.nvim auto-installs plugins on first open
tmux && prefix + I      # Install tmux plugins via TPM (prefix is C-a)
```

Update dotfiles:
```bash
dots    # alias: git add . && commit with date && push from ~/dotfiles
```

## Architecture

### Cross-platform split

The OS split is the core architectural decision:
- **Brewfile** + **Brewfile.cloud** + **Brewfile.k8s** + **Brewfile.gui** — macOS only. `install.sh` calls `brew bundle` for the base file always, and the others conditionally based on `--no-cloud`/`--no-k8s`/`--no-gui` flags.
- **install.sh section 6b** — Linux only. Downloads SRE tool binaries (k9s, lazygit, stern, delta, etc.) directly from GitHub releases into `$HOME/.local/bin` — no sudo required. K8s tools gated by `$INSTALL_K8S`, cloud tools by `$INSTALL_CLOUD`.
- **zshrc** — single file with `if [[ "$OSTYPE" == "darwin"* ]]` guards for macOS-specific PATH entries and tools.

### Symlinks (created by install.sh)

All config lives in `~/dotfiles/` and is symlinked into place:
```
~/.zshrc                    -> ~/dotfiles/zshrc
~/.tmux.conf                -> ~/dotfiles/tmux.conf
~/.gitconfig                -> ~/dotfiles/.gitconfig
~/.config/nvim              -> ~/dotfiles/config/nvim/
~/.config/starship.toml     -> ~/dotfiles/config/starship/starship.toml
~/.config/direnv/direnv.toml -> ~/dotfiles/config/direnv/direnv.toml
~/.claude/settings.json     -> ~/dotfiles/config/claude/settings.json
~/.claude/statusline.sh     -> ~/dotfiles/config/claude/statusline.sh
~/.config/wezterm/wezterm.lua -> ~/dotfiles/config/wezterm/wezterm.lua
~/.ssh/colors.conf          -> ~/dotfiles/config/ssh/colors.conf
```

### zshrc load order

1. PATH setup (fzf bin and `~/.local/bin` prioritized to avoid version conflicts)
2. OS-specific PATHs (macOS: Homebrew, jenv, Android, Go; Linux: `~/.local/go`)
3. Tool init: `starship`, `direnv`
4. Lazy-loaded: `gcloud`/`gsutil`/`bq` (deferred until first call), `fnm` (Node version manager)
5. Plugins: `zsh-autosuggestions`, `zsh-syntax-highlighting` (searched across `/usr/share`, `/usr/local/share`, `/opt/homebrew/share`)
6. FZF keybindings (version-guarded: requires ≥0.48 for `fzf --zsh`)
7. Aliases and functions (`t` tmux sessionizer, `sp`/`ssh-pick`)
8. `zoxide init` (must be last)
9. Local overrides: `~/.zshrc.local` (not synced — host-specific config)

### Neovim config (`config/nvim/`)

Entry: `init.lua` → loads `config.lazy`, `config.options`, `config.keymaps`, `config.autocmds`.

Plugin files in `lua/plugins/`:
- `lsp.lua` — Mason + mason-lspconfig + nvim-lspconfig (nvim 0.11+ API via `vim.lsp.enable()`). gopls and terraformls are macOS-only (gated by `vim.uv.os_uname().sysname == "Darwin"`).
- `editor.lua` — conform.nvim (format on save: black, goimports, jq, terraform_fmt, stylua) + nvim-lint (flake8, yamllint, shellcheck, tflint)
- `telescope.lua` — fuzzy finder
- `treesitter.lua` — syntax highlighting
- `git.lua` — gitsigns + vim-fugitive
- `oil.lua` — file explorer (open with `-`)
- `which-key.lua` — keybinding popup on `<Space>`
- `ui.lua`, `colorscheme.lua` — lualine, Catppuccin Mocha theme

Leader key: `<Space>`. Key LSP bindings active on `LspAttach`: `gd` (definition), `gr` (references), `K` (hover), `<Leader>ca` (code action), `<Leader>rn` (rename).

### Tmux (`tmux.conf`)

Prefix remapped to `C-a`. Key bindings:
- `|` / `-` — split horizontally/vertically (preserves cwd)
- `M-h/j/k/l` — navigate panes without prefix
- `M-1..5` — jump to window by number
- `Prefix + r` — reload config
- Copy mode vi-style; clipboard auto-detected (pbcopy on Mac, xclip/xsel on Linux)

Plugins via TPM: tmux-sensible, tmux-resurrect, tmux-continuum (auto-save every 15min, auto-restore on start), tmux-yank.

### Language environment management

| Language | Tool | Notes |
|---|---|---|
| Node.js | `fnm` | Reads `.nvmrc` / `.node-version` per project. Init via `eval "$(fnm env --use-on-cd --shell zsh)"` |
| Python | `uv` | Replaces pip/virtualenv/pyenv. Use `uv venv` + `uv pip install` per project |
| Go | `GOPATH=$HOME/go` | Managed via `go.mod`; gopls LSP on macOS |
| Java | `jenv` + `openjdk@17` | Add `.java-version` file per project |

### `config/bin/cn`

Wrapper for `@continuedev/cli` — finds the fnm/nvm node binary without requiring nvm to be loaded in the current shell. Update this if the node version manager changes.

## Key conventions

- **Brewfile/Brewfile.{cloud,k8s,gui} are macOS-only** — never add Linux-specific packages here; add them to the apt block or the binary download section in `install.sh` section 6b. New macOS packages: classify into the right Brewfile split — base for always-needed, `.cloud` for IaC/cloud CLIs, `.k8s` for kubernetes/containers, `.gui` for Mac apps + VSCode extensions.
- **`pinentry-mac` in Security section** — macOS-only, intentional, fine since Brewfile is macOS-only.
- **`~/.zshrc.local`** — for machine-specific config that should not be committed (tokens, host-specific aliases, etc.).
- **Consistent theme** — Catppuccin Mocha across nvim, tmux status bar, starship, and git delta. Keep new UI additions on this theme.
- **`jenv` + `openjdk@17`** — only the pinned version is in Brewfile. Add explicit `openjdk@XX` entries if additional Java versions are needed; do not use the unversioned `openjdk` formula.
