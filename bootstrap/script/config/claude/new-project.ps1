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

# Global personal + company prefs are auto-loaded from ~/.claude/rules/ — no per-project
# symlinks needed anymore (they were gitignored stubs and created project spam).

git add -A
git commit -q -m "Initial project setup"

Write-Host "Created $ProjectDir"
Write-Host "  - git initialized"
Write-Host "  - .gitignore created"
Write-Host "  - CLAUDE.md created"
Write-Host "  - CLAUDE-personal-project..md created (gitignored)"
