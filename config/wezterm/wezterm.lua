-- =============================================================================
-- WezTerm config — kr0nicas SRE 2026
-- Cross-platform: macOS + Windows (WSL2)
-- Tema: Catppuccin Mocha · Font: Hack Nerd Font (macOS) / JetBrainsMono Nerd Font (WSL2)
-- =============================================================================

local wezterm = require("wezterm")
local act     = wezterm.action
local config  = wezterm.config_builder()

-- =============================================================================
-- DETECCIÓN DE PLATAFORMA
-- =============================================================================
local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_mac     = wezterm.target_triple:find("apple")   ~= nil

-- =============================================================================
-- SHELL POR DEFECTO
-- =============================================================================
if is_windows then
  -- WSL2: abre directamente en Ubuntu/Debian con zsh
  config.default_prog = { "wsl.exe", "--", "zsh", "-l" }
  config.default_cwd  = wezterm.home_dir
elseif is_mac then
  config.default_prog = { "/bin/zsh", "-l" }
end

-- =============================================================================
-- APARIENCIA — Catppuccin Mocha
-- =============================================================================
config.color_scheme = "Catppuccin Mocha"

config.window_background_opacity = 0.97
config.macos_window_background_blur = 20   -- solo macOS

-- La Nerd Font disponible NO es la misma en cada plataforma: en macOS el Brewfile
-- instala Hack, pero en WSL2 quien renderiza es Windows y ahí install-fonts-windows.ps1
-- instala JetBrainsMono. Pedir la que no está hace que WezTerm caiga en silencio a su
-- fuente por defecto y el prompt salga con "?" en vez de iconos. El fallback cubre
-- además la caja que tenga la otra instalada.
local font_stack = is_windows
    and { "JetBrainsMono Nerd Font", "Hack Nerd Font" }
    or  { "Hack Nerd Font", "JetBrainsMono Nerd Font" }

config.font = wezterm.font_with_fallback(font_stack, { weight = "Regular" })
config.font_size = is_windows and 11.0 or 14.0

config.line_height    = 1.15
config.cell_width     = 1.0
config.freetype_load_flags = "NO_HINTING"

-- =============================================================================
-- VENTANA Y PESTAÑAS
-- =============================================================================
config.window_padding = { left = 10, right = 10, top = 8, bottom = 8 }

-- Decoraciones minimalistas
config.window_decorations = is_mac and "RESIZE" or "TITLE | RESIZE"

-- Tab bar
config.enable_tab_bar                 = true
config.use_fancy_tab_bar              = false
config.hide_tab_bar_if_only_one_tab   = true
config.tab_bar_at_bottom              = true
config.tab_max_width                  = 32

config.colors = {
  tab_bar = {
    background = "#181825",   -- Catppuccin Mocha mantle
    active_tab = {
      bg_color  = "#cba6f7",  -- mauve
      fg_color  = "#1e1e2e",
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = "#313244",   -- surface0
      fg_color = "#a6adc8",   -- subtext1
    },
    inactive_tab_hover = {
      bg_color = "#45475a",   -- surface1
      fg_color = "#cdd6f4",
    },
    new_tab = {
      bg_color = "#181825",
      fg_color = "#6c7086",   -- overlay0
    },
  },
}

-- Título de pestaña: muestra proceso + hostname si es SSH
wezterm.on("format-tab-title", function(tab)
  local pane  = tab.active_pane
  local title = pane.title
  -- Si el título viene vacío, usa el proceso
  if title == "" then
    title = pane.foreground_process_name:gsub(".*/", "")
  end
  local icon = tab.is_active and "󰄾 " or "  "
  return icon .. title
end)

-- =============================================================================
-- COLORES SSH — lee config/ssh/colors.conf
-- OSC 11 es nativo en WezTerm, el wrapper de zshrc funciona sin hacks.
-- Este bloque añade además el título de ventana con el entorno.
-- =============================================================================
wezterm.on("user-var-changed", function(window, pane, name, value)
  -- Puedes emitir variables desde zshrc con: printf '\033]1337;SetUserVar=%s=%s\007' KEY VALUE
  if name == "SSH_ENV" then
    local labels = {
      PRODUCCION = "🔴 PROD",
      STAGING    = "🟠 STAGING",
      QA         = "🟡 QA",
      DESARROLLO = "🔵 DEV",
      GCP        = "🔵 GCP",
      AWS        = "🟢 AWS",
      VPS        = "🟣 VPS",
      BASTION    = "⚡ BASTION",
    }
    local label = labels[value] or ("🖥  " .. value)
    window:set_title(label)
  end
end)

-- =============================================================================
-- SCROLLBACK Y RENDIMIENTO
-- =============================================================================
config.scrollback_lines          = 10000
config.enable_scroll_bar         = false
config.audible_bell              = "Disabled"
config.visual_bell               = { fade_in_duration_ms = 0, fade_out_duration_ms = 75 }
config.front_end                 = "WebGpu"   -- GPU rendering
config.animation_fps             = 60
config.cursor_blink_rate         = 500
config.default_cursor_style      = "BlinkingBar"

-- =============================================================================
-- KEYBINDINGS
-- Leader = CTRL+A (igual que tmux)
-- =============================================================================
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1500 }

config.keys = {
  -- Splits
  { key = "|", mods = "LEADER",      action = act.SplitHorizontal { domain = "CurrentPaneDomain" } },
  { key = "-", mods = "LEADER",      action = act.SplitVertical   { domain = "CurrentPaneDomain" } },

  -- Navegar panes (Alt + hjkl, igual que tmux)
  { key = "h", mods = "ALT",         action = act.ActivatePaneDirection "Left"  },
  { key = "j", mods = "ALT",         action = act.ActivatePaneDirection "Down"  },
  { key = "k", mods = "ALT",         action = act.ActivatePaneDirection "Up"    },
  { key = "l", mods = "ALT",         action = act.ActivatePaneDirection "Right" },

  -- Resize panes
  { key = "H", mods = "LEADER",      action = act.AdjustPaneSize { "Left",  5 } },
  { key = "J", mods = "LEADER",      action = act.AdjustPaneSize { "Down",  5 } },
  { key = "K", mods = "LEADER",      action = act.AdjustPaneSize { "Up",    5 } },
  { key = "L", mods = "LEADER",      action = act.AdjustPaneSize { "Right", 5 } },

  -- Pestañas
  { key = "c", mods = "LEADER",      action = act.SpawnTab "CurrentPaneDomain" },
  { key = "x", mods = "LEADER",      action = act.CloseCurrentPane { confirm = true } },
  { key = "n", mods = "LEADER",      action = act.ActivateTabRelative(1)  },
  { key = "p", mods = "LEADER",      action = act.ActivateTabRelative(-1) },
  { key = "1", mods = "ALT",         action = act.ActivateTab(0) },
  { key = "2", mods = "ALT",         action = act.ActivateTab(1) },
  { key = "3", mods = "ALT",         action = act.ActivateTab(2) },
  { key = "4", mods = "ALT",         action = act.ActivateTab(3) },
  { key = "5", mods = "ALT",         action = act.ActivateTab(4) },

  -- Copy mode (vi-style)
  { key = "[", mods = "LEADER",      action = act.ActivateCopyMode },

  -- Zoom pane
  { key = "z", mods = "LEADER",      action = act.TogglePaneZoomState },

  -- Recargar config
  { key = "r", mods = "LEADER",      action = act.ReloadConfiguration },

  -- Copiar/pegar
  { key = "c", mods = "CTRL|SHIFT",  action = act.CopyTo  "Clipboard" },
  { key = "v", mods = "CTRL|SHIFT",  action = act.PasteFrom "Clipboard" },

  -- Búsqueda
  { key = "f", mods = "CTRL|SHIFT",  action = act.Search { CaseInSensitiveString = "" } },
}

-- =============================================================================
-- MOUSE
-- =============================================================================
config.mouse_bindings = {
  -- Click derecho pega (modo terminal clásico)
  {
    event  = { Down = { streak = 1, button = "Right" } },
    mods   = "NONE",
    action = act.PasteFrom "Clipboard",
  },
}

-- =============================================================================
-- HYPERLINKS automáticos
-- =============================================================================
config.hyperlink_rules = wezterm.default_hyperlink_rules()
-- GCP / AWS / GitHub links detectados automáticamente

return config
