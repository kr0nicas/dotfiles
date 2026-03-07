# ==============================================================================
# INSTALAR NERD FONTS EN WINDOWS (para WSL)
# ==============================================================================
# Instala JetBrainsMono Nerd Font por usuario (no requiere Administrador).
#
# Ejecutar desde WSL:
#   powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w ~/dotfiles/install-fonts-windows.ps1)"
#
# O desde PowerShell en Windows:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\install-fonts-windows.ps1
# ==============================================================================

$ErrorActionPreference = "Stop"

$FONT_NAME   = "JetBrainsMono"
$TEMP_DIR    = "$env:TEMP\nerd-fonts-install"
$ZIP_PATH    = "$TEMP_DIR\$FONT_NAME.zip"
$EXTRACT_DIR = "$TEMP_DIR\$FONT_NAME"

# Instalacion por usuario, no requiere admin
$USER_FONTS = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$REG_PATH   = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

Write-Host ""
Write-Host "=== Nerd Fonts Installer (WSL) ===" -ForegroundColor Cyan
Write-Host ""

# Ultima version desde GitHub
Write-Host "  Buscando ultima version..." -ForegroundColor Blue
$release      = Invoke-RestMethod "https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest"
$version      = $release.tag_name
$download_url = "https://github.com/ryanoasis/nerd-fonts/releases/download/$version/$FONT_NAME.zip"
Write-Host "  Version: $version" -ForegroundColor Green

# Crear directorios
New-Item -ItemType Directory -Force -Path $EXTRACT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $USER_FONTS  | Out-Null

# Asegurar clave de registro
if (-not (Test-Path $REG_PATH)) {
    New-Item -Path $REG_PATH -Force | Out-Null
}

# Descargar
Write-Host "  Descargando $FONT_NAME.zip..." -ForegroundColor Blue
$ProgressPreference = "SilentlyContinue"
Invoke-WebRequest -Uri $download_url -OutFile $ZIP_PATH

# Extraer
Write-Host "  Extrayendo..." -ForegroundColor Blue
Expand-Archive -Path $ZIP_PATH -DestinationPath $EXTRACT_DIR -Force

# Filtrar fuentes (excluir variantes Windows Compatible)
$fonts = Get-ChildItem -Path $EXTRACT_DIR -Include "*.ttf","*.otf" -Recurse |
    Where-Object { $_.Name -notmatch "Windows Compatible" }

if ($fonts.Count -eq 0) {
    Write-Host "  ERROR: No se encontraron archivos de fuente." -ForegroundColor Red
    exit 1
}

Write-Host "  Instalando $($fonts.Count) fuentes en $USER_FONTS..." -ForegroundColor Blue

foreach ($font in $fonts) {
    $dest     = Join-Path $USER_FONTS $font.Name
    Copy-Item -Path $font.FullName -Destination $dest -Force
    $reg_name = "$($font.BaseName) (TrueType)"
    Set-ItemProperty -Path $REG_PATH -Name $reg_name -Value $dest -Force
}

Write-Host "  OK: $($fonts.Count) fuentes instaladas." -ForegroundColor Green

# Limpiar temporales
Remove-Item -Recurse -Force $TEMP_DIR -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Listo ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Fuente: JetBrainsMono Nerd Font" -ForegroundColor Green
Write-Host "  Ubicacion: $USER_FONTS" -ForegroundColor Blue
Write-Host ""
Write-Host "  Configura tu terminal:" -ForegroundColor Yellow
Write-Host "    Windows Terminal: Ctrl+Coma -> perfil WSL -> Appearance -> Font face"
Write-Host "    -> escribir: JetBrainsMono Nerd Font"
Write-Host ""
Write-Host "    VS Code settings.json:"
Write-Host "    terminal.integrated.fontFamily: JetBrainsMono Nerd Font"
Write-Host ""
Write-Host "  Cierra y reabre Windows Terminal para que detecte las fuentes." -ForegroundColor Yellow
Write-Host ""
