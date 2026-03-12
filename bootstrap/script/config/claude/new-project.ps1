#
# Creates a new project with git repo and CLAUDE.md template in current directory.
# Usage: .\new-project.ps1 <project-name> [description]
#

$ErrorActionPreference = "Stop"

$CodeDir = Get-Location
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $args[0]) {
  Write-Host "Creates a new project with git repo and CLAUDE.md template in current folder."
  Write-Host ""
  Write-Host "Usage: .\new-project.ps1 <project-name> [description]"
  exit 1
}

$ProjectName = $args[0]
$ProjectDir = Join-Path $CodeDir $ProjectName
$Description = if ($args[1]) { $args[1] } else { "" }

if (Test-Path $ProjectDir) {
  Write-Host "Error: $ProjectDir already exists" -ForegroundColor Red
  exit 1
}

New-Item -ItemType Directory -Path $ProjectDir -Force | Out-Null
Set-Location $ProjectDir

git init -q

"" | Set-Content .gitignore -Encoding UTF8

# CLAUDE.md from template
$projectTemplate = Get-Content (Join-Path $ScriptDir "project-en.md") -Raw
$projectTemplate = $projectTemplate -replace '\{\{PROJECT_NAME\}\}', $ProjectName
$descriptionText = if ($Description) { $Description } else { "TODO: Add project description" }
$projectTemplate = $projectTemplate -replace '\{\{DESCRIPTION\}\}', $descriptionText
$projectTemplate | Set-Content "CLAUDE.md" -Encoding UTF8

# CLAUDE-personal-project..md from template
$personalTemplate = Get-Content (Join-Path $ScriptDir "personal-en.md") -Raw
$personalTemplate = $personalTemplate -replace '\{\{PROJECT_NAME\}\}', $ProjectName
$personalTemplate | Set-Content "CLAUDE-personal-project..md" -Encoding UTF8

# Symlinks to global CLAUDE files
$GlobalDjtl = Join-Path $env:USERPROFILE ".claude\CLAUDE-djtl.md"
$GlobalPersonal = Join-Path $env:USERPROFILE ".claude\CLAUDE.md"

$canSymlink = $false
try {
  # Test if we can create symlinks (requires Developer Mode or admin)
  $testLink = Join-Path $ProjectDir ".symlink-test"
  $testTarget = Join-Path $ProjectDir "CLAUDE.md"
  New-Item -ItemType SymbolicLink -Path $testLink -Target $testTarget -ErrorAction Stop | Out-Null
  Remove-Item $testLink
  $canSymlink = $true
} catch {
  $canSymlink = $false
}

if ($canSymlink) {
  New-Item -ItemType SymbolicLink -Path "CLAUDE-djtl-global..md" -Target $GlobalDjtl | Out-Null
  New-Item -ItemType SymbolicLink -Path "CLAUDE-personal-global..md" -Target $GlobalPersonal | Out-Null
} else {
  Write-Host "[WARN] Cannot create symlinks (enable Developer Mode or run as admin)." -ForegroundColor Yellow
  Write-Host "[WARN] Copying global CLAUDE files instead. Run bootstrap to update." -ForegroundColor Yellow
  if (Test-Path $GlobalDjtl) { Copy-Item $GlobalDjtl "CLAUDE-djtl-global..md" }
  if (Test-Path $GlobalPersonal) { Copy-Item $GlobalPersonal "CLAUDE-personal-global..md" }
}

git add -A
git commit -q -m "Initial project setup"

Write-Host "Created $ProjectDir"
Write-Host "  - git initialized"
Write-Host "  - .gitignore created"
Write-Host "  - CLAUDE.md created"
Write-Host "  - CLAUDE-djtl-global..md -> $GlobalDjtl"
Write-Host "  - CLAUDE-personal-global..md -> $GlobalPersonal"
Write-Host "  - CLAUDE-personal-project..md created (gitignored)"
