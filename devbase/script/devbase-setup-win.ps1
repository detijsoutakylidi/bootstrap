#Requires -RunAsAdministrator

#
# Base bootstrap for a fresh Windows machine.
#
# Installs: winget (if missing), jq, ripgrep, git, gh.
# Configures: global gitignore.
# Run this FIRST, before the Claude or VS Code scripts.
#

$ErrorActionPreference = "Stop"

function Write-Info  { param($msg) Write-Host "> $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Head  { param($msg) Write-Host "--- $msg ---" }

# --- winget --------------------------------------------------

Write-Head "winget (App Installer)"

if (Get-Command winget -ErrorAction SilentlyContinue) {
  Write-Skip "Already installed: $(winget --version)"
} else {
  Write-Info "winget not found. It ships with App Installer from the Microsoft Store."
  Write-Info "Opening Microsoft Store page..."
  Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
  Write-Fail "Install App Installer from the Store, then re-run this script."
  exit 1
}

Write-Host ""

# --- jq ------------------------------------------------------

Write-Head "jq"

if (Get-Command jq -ErrorAction SilentlyContinue) {
  Write-Skip "Already installed: $(jq --version 2>&1)"
} else {
  Write-Info "Installing jq via winget..."
  winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
  Write-Ok "jq installed"
}

Write-Host ""

# --- ripgrep -------------------------------------------------

Write-Head "ripgrep"

if (Get-Command rg -ErrorAction SilentlyContinue) {
  Write-Skip "Already installed: $(rg --version | Select-Object -First 1)"
} else {
  Write-Info "Installing ripgrep via winget..."
  winget install --id BurntSushi.ripgrep.MSVC --accept-source-agreements --accept-package-agreements
  Write-Ok "ripgrep installed"
}

Write-Host ""

# --- Git for Windows -----------------------------------------

Write-Head "Git"

if (Get-Command git -ErrorAction SilentlyContinue) {
  Write-Skip "Already installed: $(git --version)"
} else {
  Write-Info "Installing Git via winget..."
  winget install --id Git.Git --accept-source-agreements --accept-package-agreements
  Write-Ok "Git installed"
}

Write-Host ""

# --- Git global config ----------------------------------------

Write-Head "Git global config"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitignoreSrc = Join-Path $ScriptDir "gitignore_global"
$GitignoreDst = Join-Path $env:USERPROFILE ".gitignore_global"

if (-not (Test-Path $GitignoreSrc)) {
  Write-Fail "gitignore_global not found in script directory"
} elseif (-not (Test-Path $GitignoreDst)) {
  Copy-Item $GitignoreSrc $GitignoreDst
  git config --global core.excludesFile $GitignoreDst
  Write-Ok "Global gitignore installed -> $GitignoreDst"
} else {
  $srcContent = (Get-Content $GitignoreSrc | Where-Object { $_.Trim() -ne "" }) -join "`n"
  $dstContent = (Get-Content $GitignoreDst | Where-Object { $_.Trim() -ne "" }) -join "`n"

  if ($srcContent -eq $dstContent) {
    git config --global core.excludesFile $GitignoreDst
    Write-Skip "Global gitignore already up to date"
  } else {
    Write-Info "Current ~/.gitignore_global:"
    Get-Content $GitignoreDst | ForEach-Object { Write-Host "    $_" }
    Write-Host ""
    Write-Info "New gitignore_global from setup:"
    Get-Content $GitignoreSrc | ForEach-Object { Write-Host "    $_" }
    Write-Host ""
    $choice = Read-Host "> [S]kip / [O]verwrite / [M]erge entry by entry? [s/o/m]"
    switch ($choice.ToLower()) {
      "o" {
        Copy-Item $GitignoreSrc $GitignoreDst -Force
        Write-Ok "Global gitignore overwritten"
      }
      "m" {
        $currentEntries = @(Get-Content $GitignoreDst | Where-Object { $_.Trim() -ne "" })
        $newEntries = @(Get-Content $GitignoreSrc | Where-Object { $_.Trim() -ne "" })
        $allEntries = @($currentEntries + $newEntries | Sort-Object -Unique)
        $merged = @()

        foreach ($entry in $allEntries) {
          $inCurrent = $currentEntries -contains $entry
          $inNew = $newEntries -contains $entry

          if ($inCurrent -and $inNew) {
            $merged += $entry
            Write-Skip "Keep: $entry (in both)"
          } elseif ($inCurrent) {
            $ans = Read-Host "> Keep `"$entry`" (only in current)? [Y/n]"
            if ($ans -ne "n" -and $ans -ne "N") { $merged += $entry }
          } else {
            $ans = Read-Host "> Add `"$entry`" (new from setup)? [Y/n]"
            if ($ans -ne "n" -and $ans -ne "N") { $merged += $entry }
          }
        }
        $merged | Set-Content $GitignoreDst
        Write-Ok "Global gitignore merged"
      }
      default {
        Write-Skip "Kept existing global gitignore"
      }
    }
    git config --global core.excludesFile $GitignoreDst
  }
}

Write-Host ""

# --- GitHub CLI ----------------------------------------------

Write-Head "GitHub CLI"

if (Get-Command gh -ErrorAction SilentlyContinue) {
  Write-Skip "Already installed: $(gh --version | Select-Object -First 1)"
} else {
  Write-Info "Installing GitHub CLI via winget..."
  winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
  Write-Ok "GitHub CLI installed"
}

Write-Host ""

# --- Summary -------------------------------------------------

Write-Head "Done"
Write-Host ""
Write-Info "Your Windows machine is now ready for:"
Write-Info "  .\claude-setup-win.ps1   (Claude ecosystem)"
Write-Info "  .\vscode-setup-win.ps1   (VS Code)"
Write-Info "  .\terminal-setup-win.ps1 (Windows Terminal)"
Write-Host ""
Write-Info "Manual step:"
Write-Info "  Run: gh auth login                       - authenticate GitHub CLI"
