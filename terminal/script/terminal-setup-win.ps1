#
# Terminal setup for Windows.
#
# Configures: Windows Terminal (Pro color scheme + defaults),
# PowerShell prompt (minimal, like zsh PROMPT='%1~ % ').
#

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Info  { param($msg) Write-Host "> $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Head  { param($msg) Write-Host "--- $msg ---" }

# --- 1. Windows Terminal settings ----------------------------

Write-Head "Windows Terminal profile"

$wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtPreviewPath  = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

# Find the active settings file
$settingsFile = $null
if (Test-Path $wtSettingsPath) { $settingsFile = $wtSettingsPath }
elseif (Test-Path $wtPreviewPath) { $settingsFile = $wtPreviewPath }

if (-not $settingsFile) {
  Write-Fail "Windows Terminal settings not found. Is Windows Terminal installed?"
  Write-Info "Install via: winget install --id Microsoft.WindowsTerminal"
} else {
  Write-Info "Found settings at: $settingsFile"

  # Read current settings (strip comments for JSON parsing)
  $rawContent = Get-Content $settingsFile -Raw
  $cleanContent = $rawContent -replace '(?m)^\s*//.*$', '' -replace '/\*[\s\S]*?\*/', ''
  $settings = $cleanContent | ConvertFrom-Json

  # Read our profile fragment
  $fragment = Get-Content "$ScriptDir\windows-terminal-profile.json" -Raw | ConvertFrom-Json

  # Merge color scheme
  if (-not $settings.schemes) { $settings | Add-Member -NotePropertyName "schemes" -NotePropertyValue @() }
  $existingScheme = $settings.schemes | Where-Object { $_.name -eq "Pro" }
  if ($existingScheme) {
    Write-Skip "Pro color scheme already exists"
  } else {
    $settings.schemes += $fragment.schemes[0]
    Write-Ok "Pro color scheme added"
  }

  # Merge profile defaults
  if (-not $settings.profiles.defaults) {
    $settings.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{}
  }
  $fragment.profiles.defaults.PSObject.Properties | ForEach-Object {
    $settings.profiles.defaults | Add-Member -NotePropertyName $_.Name -NotePropertyValue $_.Value -Force
  }
  Write-Ok "Profile defaults updated (font: Cascadia Mono 18, Pro scheme, no bell)"

  # Write back
  $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
  Write-Ok "Windows Terminal settings saved"
}

Write-Host ""

# --- 2. PowerShell prompt ------------------------------------

Write-Head "PowerShell prompt"

$profilePath = $PROFILE.CurrentUserAllHosts
$promptBlock = @'

# prompt --- minimal, shows current directory name
function prompt {
  "$((Get-Item .).Name) > "
}
'@

if (Test-Path $profilePath) {
  $content = Get-Content $profilePath -Raw
  if ($content -match 'function prompt') {
    Write-Skip "Prompt function already defined in $profilePath"
  } else {
    Add-Content -Path $profilePath -Value $promptBlock
    Write-Ok "Prompt added to $profilePath"
  }
} else {
  $profileDir = Split-Path $profilePath
  if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
  Set-Content -Path $profilePath -Value $promptBlock.TrimStart()
  Write-Ok "Created $profilePath with minimal prompt"
}

Write-Host ""
Write-Ok "Terminal setup complete! Open a new Windows Terminal window to see changes."
