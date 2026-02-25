#
# VS Code setup for Windows.
#
# Prerequisites: run devbase-setup-win.ps1 first (winget).
#
# Installs: VS Code, extensions, config files, file associations.
#

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VscodeConfigDir = "$env:APPDATA\Code\User"

function Write-Info  { param($msg) Write-Host "> $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Head  { param($msg) Write-Host "--- $msg ---" }

# --- Preflight: winget must exist ----------------------------

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Fail "winget not found. Run devbase-setup-win.ps1 first."
  exit 1
}

# --- 1. VS Code ---------------------------------------------

Write-Head "VS Code"

if (Get-Command code -ErrorAction SilentlyContinue) {
  Write-Skip "VS Code already installed"
} else {
  $installed = winget list --id Microsoft.VisualStudioCode 2>$null | Select-String "Microsoft.VisualStudioCode"
  if ($installed) {
    Write-Skip "VS Code already installed (code CLI not in PATH --- restart terminal)"
  } else {
    Write-Info "Installing VS Code via winget..."
    winget install --id Microsoft.VisualStudioCode --accept-source-agreements --accept-package-agreements
    Write-Ok "VS Code installed"
    Write-Info "Restart your terminal so 'code' is on PATH, then re-run this script."
    exit 0
  }
}

Write-Host ""

# --- 2. Projects directory ----------------------------------

Write-Head "Projects directory"

$defaultProjectsDir = "$env:USERPROFILE\Projects"
$answer = Read-Host "> Projects directory (default: $defaultProjectsDir)"
$ProjectsDir = if ($answer) { $answer } else { $defaultProjectsDir }

if (Test-Path $ProjectsDir) {
  Write-Skip "Projects directory exists: $ProjectsDir"
} else {
  Write-Info "Creating $ProjectsDir..."
  New-Item -ItemType Directory -Path $ProjectsDir -Force | Out-Null
  Write-Ok "Created $ProjectsDir"
}

Write-Host ""

# --- 3. Essential extensions --------------------------------

Write-Head "Essential extensions"

$installedExtensions = (code --list-extensions 2>$null) -join "`n"

function Install-Extension {
  param($ExtId, $Name)
  if ($installedExtensions -match "(?i)^$([regex]::Escape($ExtId))$") {
    Write-Skip "$Name already installed"
  } else {
    Write-Info "Installing $Name..."
    code --install-extension $ExtId --force
    Write-Ok "$Name installed"
  }
}

Install-Extension "anthropic.claude-code"           "Claude Code"
Install-Extension "catppuccin.catppuccin-vsc"       "Catppuccin Theme"
Install-Extension "alefragnani.project-manager"     "Project Manager"
Install-Extension "mrmlnc.vscode-duplicate"         "Duplicate Action"
Install-Extension "natizyskunk.sftp"                "SFTP"
Install-Extension "johnpapa.vscode-peacock"         "Peacock"

Write-Host ""

# --- 4. Optional extensions ---------------------------------

Write-Head "Optional extensions"

function Ask-Install {
  param($ExtId, $Name)
  if ($installedExtensions -match "(?i)^$([regex]::Escape($ExtId))$") {
    Write-Skip "$Name already installed"
    return
  }
  $answer = Read-Host "> Install $Name? [y/N]"
  if ($answer -match '^[Yy]$') {
    code --install-extension $ExtId --force
    Write-Ok "$Name installed"
  }
}

Ask-Install -ExtId "bmewburn.vscode-intelephense-client" -Name "Intelephense (PHP)"
Ask-Install -ExtId "britesnow.vscode-toggle-quotes"     -Name "Toggle Quotes"
Ask-Install -ExtId "hashicorp.terraform"                 -Name "Terraform"

Write-Host ""

# --- 5. Config files ----------------------------------------

Write-Head "Config files"

if (-not (Test-Path $VscodeConfigDir)) {
  New-Item -ItemType Directory -Path $VscodeConfigDir -Force | Out-Null
}

# settings.json --- substitute placeholders
$settingsContent = Get-Content "$ScriptDir\settings.json" -Raw
$settingsContent = $settingsContent -replace '__HOME__', ($env:USERPROFILE -replace '\\', '/')
$settingsContent = $settingsContent -replace '__PROJECTS_DIR__', ($ProjectsDir -replace '\\', '/')

# Patch macOS-specific settings for Windows
$settingsContent = $settingsContent -replace '"window\.nativeFullScreen": false,\s*\n', ''
$settingsContent = $settingsContent -replace '"editor\.multiCursorModifier": "ctrlCmd"', '"editor.multiCursorModifier": "alt"'

Set-Content -Path "$VscodeConfigDir\settings.json" -Value $settingsContent -Encoding UTF8
Write-Ok "settings.json installed"

# keybindings --- use Windows variant (ctrl instead of cmd)
Copy-Item "$ScriptDir\keybindings-win.json" "$VscodeConfigDir\keybindings.json" -Force
Write-Ok "keybindings.json installed (Windows variant)"

Write-Host ""

# --- 6. File associations -----------------------------------

Write-Head "File associations"

$extensions = @(".json", ".xml", ".js", ".md", ".jsonl", ".srt", ".pub", ".tf", ".tfstate", ".vtt")

$prevErrorPref = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

foreach ($ext in $extensions) {
  $current = (cmd /c "assoc $ext" 2>$null) -replace "^$([regex]::Escape($ext))=", ""

  # Check if already associated with VS Code
  if ($current -and ($current -notmatch "not found")) {
    $handler = (cmd /c "ftype $current" 2>$null)
    if ($handler -match "Code") {
      Write-Skip "$ext already opens in VS Code"
      continue
    }
  }

  Write-Info "Setting $ext -> VS Code..."
  cmd /c "assoc $ext=VSCode$($ext.TrimStart('.'))" 2>$null | Out-Null
  cmd /c "ftype VSCode$($ext.TrimStart('.'))=`"$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe`" `"%1`"" 2>$null | Out-Null
  Write-Ok "$ext -> VS Code"
}

$ErrorActionPreference = $prevErrorPref

Write-Host ""
Write-Ok "VS Code setup complete!"
