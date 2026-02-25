#
# Claude ecosystem bootstrap for Windows.
#
# Prerequisites: run devbase-setup-win.ps1 first (winget, jq, gh).
#
# Installs: Claude Code (native), Claude Desktop,
# and opens Claude in Chrome extension page.
# (CodexBar is macOS-only, skipped on Windows.)
#

$ErrorActionPreference = "Stop"

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

# --- Install functions ---------------------------------------

function Install-ClaudeCode {
  if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Skip "Already installed: claude $(claude --version 2>&1)"
    return "skip"
  }
  Write-Info "Installing Claude Code via native installer..."
  try {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Write-Ok "Claude Code installed"
    return "ok"
  } catch {
    Write-Fail "Claude Code install failed: $_"
    return "fail"
  }
}

function Install-ClaudeDesktop {
  $installed = winget list --id Anthropic.Claude 2>$null | Select-String "Anthropic.Claude"
  if ($installed) {
    Write-Skip "Already installed: Claude Desktop"
    return "skip"
  }
  Write-Info "Installing Claude Desktop via winget..."
  try {
    winget install --id Anthropic.Claude --accept-source-agreements --accept-package-agreements
    Write-Ok "Claude Desktop installed"
    return "ok"
  } catch {
    Write-Fail "Claude Desktop install failed: $_"
    return "fail"
  }
}

function Install-ChromeExt {
  Write-Info "Opening Chrome Web Store for Claude in Chrome..."
  Start-Process "https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn"
  Write-Ok "Chrome Web Store opened --- install manually"
  return "ok"
}

# --- Main ----------------------------------------------------

Write-Head "Claude ecosystem bootstrap"
Write-Host ""

$steps = @(
  @{ Key = "ClaudeCode";    Label = "Claude Code (native installer)" },
  @{ Key = "ClaudeDesktop"; Label = "Claude Desktop" },
  @{ Key = "ChromeExt";     Label = "Claude in Chrome extension" }
)

$results = @{}

foreach ($step in $steps) {
  Write-Head $step.Label
  $fn = "Install-$($step.Key)"
  $results[$step.Key] = & $fn
  Write-Host ""
}

# --- Summary -------------------------------------------------

Write-Head "Summary"
Write-Host ""

foreach ($step in $steps) {
  $status = $results[$step.Key]
  switch ($status) {
    "ok"   { Write-Ok   $step.Label }
    "skip" { Write-Skip "$($step.Label) (already installed)" }
    "fail" { Write-Fail $step.Label }
  }
}

# --- Manual steps --------------------------------------------

Write-Host ""
Write-Head "Manual steps needed"
Write-Host ""

Write-Info "Run: claude login                       -> authenticate Claude Code"
Write-Info "Open Claude Desktop                     -> sign in with your account"
Write-Info "Chrome Web Store                        -> click 'Add to Chrome' if not done"
Write-Info "(CodexBar is macOS-only --- not available on Windows)"
