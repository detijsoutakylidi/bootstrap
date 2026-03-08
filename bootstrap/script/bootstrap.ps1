#
# Unified Windows bootstrap.
#
# Installs system tools and configures user environment in one pass.
#
# Install from anywhere:
#   & ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1)))
#   & ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1))) --install
#   & ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1))) --configure
#
# Run specific sections:
#   .\bootstrap.ps1 --vscode                   # VS Code only (install + configure)
#   .\bootstrap.ps1 --configure --terminal     # configure terminal only
#   .\bootstrap.ps1 --install --base --vscode  # install base + vscode only
#
# Or run locally:
#   .\bootstrap\script\bootstrap.ps1 [--install | --configure] [--base] [--vscode] [--claude] [--terminal]
#

$ErrorActionPreference = "Stop"

$REPO_RAW_URL = "https://raw.githubusercontent.com/detijsoutakylidi/bootstrap/main/bootstrap/script/config"

# Detect local config dir (works when run from repo checkout)
$ScriptDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $null }
$LocalConfigDir = if ($ScriptDir) { Join-Path $ScriptDir "config" } else { $null }

# Temp dir for downloaded config files — cleaned up on exit
$TmpDir = Join-Path $env:TEMP "bootstrap-$(Get-Random)"
New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

# ─── Logging ──────────────────────────────────────────────

function Write-Info  { param($msg) Write-Host "> $msg" -ForegroundColor Blue }
function Write-Ok    { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Skip  { param($msg) Write-Host "[SKIP] $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Head  { param($msg) Write-Host ""; Write-Host "--- $msg ---" }

# ─── Config fetcher ───────────────────────────────────────

function Get-Config {
  param([string]$SubPath)

  if ($LocalConfigDir) {
    $localPath = Join-Path $LocalConfigDir $SubPath
    if (Test-Path $localPath) { return $localPath }
  }

  $dest = Join-Path $TmpDir $SubPath
  $destDir = Split-Path $dest
  if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }

  try {
    Invoke-RestMethod "$REPO_RAW_URL/$SubPath" -OutFile $dest
    return $dest
  } catch {
    return $null
  }
}

# ─── Argument parsing ─────────────────────────────────────

$PhaseInstall = $false
$PhaseConfigure = $false
$SecBase = $false; $SecVscode = $false; $SecClaude = $false; $SecTerminal = $false
$SectionSpecified = $false
$Extended = $false

foreach ($a in $args) {
  switch ($a) {
    "--install"   { $PhaseInstall = $true }
    "--configure" { $PhaseConfigure = $true }
    "--base"      { $SecBase = $true; $SectionSpecified = $true }
    "--vscode"    { $SecVscode = $true; $SectionSpecified = $true }
    "--claude"    { $SecClaude = $true; $SectionSpecified = $true }
    "--terminal"  { $SecTerminal = $true; $SectionSpecified = $true }
    "--extended"  { $Extended = $true }
    default {
      Write-Fail "Unknown option: $a"
      Write-Host "Usage: .\bootstrap.ps1 [--install | --configure] [--base] [--vscode] [--claude] [--terminal] [--extended]"
      exit 1
    }
  }
}

if (-not $SectionSpecified) {
  $SecBase = $true; $SecVscode = $true; $SecClaude = $true; $SecTerminal = $true
}

# Default: auto-detect phase when neither specified
if (-not $PhaseInstall -and -not $PhaseConfigure) {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

  if ($isAdmin) {
    $PhaseInstall = $true
    $PhaseConfigure = $true
  } else {
    Write-Info "Non-admin session detected --- running in configure-only mode."
    Write-Info "For system installs, run PowerShell as Administrator: .\bootstrap.ps1 --install"
    Write-Host ""
    $PhaseConfigure = $true
  }
}

# ═══════════════════════════════════════════════════════════
# INSTALL PHASE
# ═══════════════════════════════════════════════════════════

function Install-Base {
  # ─── winget ───
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

  # ─── jq ───
  Write-Head "jq"

  if (Get-Command jq -ErrorAction SilentlyContinue) {
    Write-Skip "Already installed: $(jq --version 2>&1)"
  } else {
    Write-Info "Installing jq via winget..."
    winget install --id jqlang.jq --accept-source-agreements --accept-package-agreements
    Write-Ok "jq installed"
  }

  # ─── ripgrep ───
  Write-Head "ripgrep"

  if (Get-Command rg -ErrorAction SilentlyContinue) {
    Write-Skip "Already installed: $(rg --version | Select-Object -First 1)"
  } else {
    Write-Info "Installing ripgrep via winget..."
    winget install --id BurntSushi.ripgrep.MSVC --accept-source-agreements --accept-package-agreements
    Write-Ok "ripgrep installed"
  }

  # ─── Git ───
  Write-Head "Git"

  if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Skip "Already installed: $(git --version)"
  } else {
    Write-Info "Installing Git via winget..."
    winget install --id Git.Git --accept-source-agreements --accept-package-agreements
    Write-Ok "Git installed"
  }

  # ─── GitHub CLI ───
  Write-Head "GitHub CLI"

  if (Get-Command gh -ErrorAction SilentlyContinue) {
    Write-Skip "Already installed: $(gh --version | Select-Object -First 1)"
  } else {
    Write-Info "Installing GitHub CLI via winget..."
    winget install --id GitHub.cli --accept-source-agreements --accept-package-agreements
    Write-Ok "GitHub CLI installed"
  }
}

function Install-Vscode {
  # ─── VS Code app ───
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

  # ─── File associations ───
  Write-Head "File associations"

  $extensions = @(".json", ".xml", ".js", ".md", ".jsonl", ".srt", ".pub", ".tf", ".tfstate", ".vtt")

  $prevErrorPref = $ErrorActionPreference
  $ErrorActionPreference = "SilentlyContinue"

  foreach ($ext in $extensions) {
    $current = (cmd /c "assoc $ext" 2>$null) -replace "^$([regex]::Escape($ext))=", ""

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
}

function Install-Claude {
  # ─── Claude Code ───
  Write-Head "Claude Code"

  if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Skip "Already installed: claude $(claude --version 2>&1)"
  } else {
    Write-Info "Installing Claude Code via native installer..."
    try {
      Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
      Write-Ok "Claude Code installed"
    } catch {
      Write-Fail "Claude Code install failed: $_"
    }
  }

  # ─── Claude Desktop ───
  Write-Head "Claude Desktop"

  $installed = winget list --id Anthropic.Claude 2>$null | Select-String "Anthropic.Claude"
  if ($installed) {
    Write-Skip "Already installed: Claude Desktop"
  } else {
    Write-Info "Installing Claude Desktop via winget..."
    try {
      winget install --id Anthropic.Claude --accept-source-agreements --accept-package-agreements
      Write-Ok "Claude Desktop installed"
    } catch {
      Write-Fail "Claude Desktop install failed: $_"
    }
  }
}

# ═══════════════════════════════════════════════════════════
# CONFIGURE PHASE
# ═══════════════════════════════════════════════════════════

function Configure-Base {
  Write-Head "Git global config"

  $GitignoreSrc = Get-Config "git/gitignore_global"
  $GitignoreDst = Join-Path $env:USERPROFILE ".gitignore_global"

  if (-not $GitignoreSrc -or -not (Test-Path $GitignoreSrc)) {
    Write-Fail "gitignore_global not found (local or remote)"
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
          $merged | Set-Content $GitignoreDst -Encoding UTF8
          Write-Ok "Global gitignore merged"
        }
        default {
          Write-Skip "Kept existing global gitignore"
        }
      }
      git config --global core.excludesFile $GitignoreDst
    }
  }
}

function Configure-Terminal {
  # ─── Windows Terminal settings ───
  Write-Head "Windows Terminal profile"

  $wtSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
  $wtPreviewPath  = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"

  $settingsFile = $null
  if (Test-Path $wtSettingsPath) { $settingsFile = $wtSettingsPath }
  elseif (Test-Path $wtPreviewPath) { $settingsFile = $wtPreviewPath }

  if (-not $settingsFile) {
    Write-Fail "Windows Terminal settings not found. Is Windows Terminal installed?"
    Write-Info "Install via: winget install --id Microsoft.WindowsTerminal"
  } else {
    Write-Info "Found settings at: $settingsFile"

    $rawContent = Get-Content $settingsFile -Raw
    $cleanContent = $rawContent -replace '(?m)^\s*//.*$', '' -replace '/\*[\s\S]*?\*/', ''
    $settings = $cleanContent | ConvertFrom-Json

    $fragmentPath = Get-Config "terminal/windows-terminal-profile.json"
    if (-not $fragmentPath -or -not (Test-Path $fragmentPath)) {
      Write-Fail "windows-terminal-profile.json not found (local or remote)"
    } else {
      $fragment = Get-Content $fragmentPath -Raw | ConvertFrom-Json

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

      $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
      Write-Ok "Windows Terminal settings saved"
    }
  }

  # ─── PowerShell prompt ───
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
    Set-Content -Path $profilePath -Value $promptBlock.TrimStart() -Encoding UTF8
    Write-Ok "Created $profilePath with minimal prompt"
  }
}

function Configure-Vscode {
  $VscodeConfigDir = "$env:APPDATA\Code\User"

  # ─── Projects directory ───
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

  # ─── Essential extensions ───
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
  Install-Extension "zaaack.markdown-editor"          "Markdown Editor"
  Install-Extension "tomoki1207.pdf"                  "PDF Viewer"

  # ─── Optional extensions (--extended) ───
  if ($Extended) {
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
    Ask-Install -ExtId "highagency.pencildev"                -Name "Pencil"
    Ask-Install -ExtId "1password.op-vscode"                 -Name "1Password"
  }

  # ─── Config files ───
  Write-Head "Config files"

  if (-not (Test-Path $VscodeConfigDir)) {
    New-Item -ItemType Directory -Path $VscodeConfigDir -Force | Out-Null
  }

  function Install-Config {
    param($Content, $Dst, $Label)

    if (-not (Test-Path $Dst)) {
      Set-Content -Path $Dst -Value $Content -Encoding UTF8
      Write-Ok "$Label installed"
    } else {
      $currentContent = Get-Content $Dst -Raw
      if ($Content.TrimEnd() -eq $currentContent.TrimEnd()) {
        Write-Skip "$Label already up to date"
      } else {
        Write-Info "$Label differs from setup version."
        Write-Info "Run a diff tool to compare, or choose:"
        Write-Host ""
        $choice = Read-Host "> [S]kip / [O]verwrite? [s/o]"
        if ($choice -match '^[Oo]$') {
          Set-Content -Path $Dst -Value $Content -Encoding UTF8
          Write-Ok "$Label overwritten"
        } else {
          Write-Skip "Kept existing $Label"
        }
      }
    }
  }

  # settings.json --- substitute placeholders
  $settingsSrc = Get-Config "vscode/settings.json"
  if ($settingsSrc -and (Test-Path $settingsSrc)) {
    $settingsContent = Get-Content $settingsSrc -Raw
    $settingsContent = $settingsContent -replace '__HOME__', ($env:USERPROFILE -replace '\\', '/')
    $settingsContent = $settingsContent -replace '__PROJECTS_DIR__', ($ProjectsDir -replace '\\', '/')

    # Patch macOS-specific settings for Windows
    $settingsContent = $settingsContent -replace '"window\.nativeFullScreen": false,\s*\n', ''
    $settingsContent = $settingsContent -replace '"editor\.multiCursorModifier": "ctrlCmd"', '"editor.multiCursorModifier": "alt"'

    Install-Config -Content $settingsContent -Dst "$VscodeConfigDir\settings.json" -Label "settings.json"
  } else {
    Write-Fail "settings.json not found (local or remote)"
  }

  # keybindings --- use Windows variant (ctrl instead of cmd)
  $keybindingsSrc = Get-Config "vscode/keybindings-win.json"
  if ($keybindingsSrc -and (Test-Path $keybindingsSrc)) {
    $keybindingsContent = Get-Content $keybindingsSrc -Raw
    Install-Config -Content $keybindingsContent -Dst "$VscodeConfigDir\keybindings.json" -Label "keybindings.json"
  } else {
    Write-Fail "keybindings-win.json not found (local or remote)"
  }
}

function Configure-Claude {
  Write-Head "Claude ecosystem"

  # ─── Chrome extension ───
  Write-Info "Opening Chrome Web Store for Claude in Chrome..."
  Start-Process "https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn"
  Write-Ok "Chrome Web Store opened --- install manually"

  # ─── Manual steps ───
  Write-Head "Manual steps needed"
  Write-Host ""
  Write-Info "Run: claude login                       -> authenticate Claude Code"
  Write-Info "Run: gh auth login                      -> authenticate GitHub CLI"
  Write-Info "Open Claude Desktop                     -> sign in with your account"
  Write-Info "Chrome Web Store                        -> click 'Add to Chrome' if not done"
  Write-Info "(CodexBar is macOS-only --- not available on Windows)"
}

# ═══════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════

try {

$phases = @()
if ($PhaseInstall) { $phases += "install" }
if ($PhaseConfigure) { $phases += "configure" }
$sections = @()
if ($SecBase) { $sections += "base" }
if ($SecVscode) { $sections += "vscode" }
if ($SecClaude) { $sections += "claude" }
if ($SecTerminal) { $sections += "terminal" }

Write-Host ""
Write-Host "+-------------------------------------+"
Write-Host "|  Windows Bootstrap"
Write-Host "|  phase: $($phases -join ' ')"
Write-Host "|  sections: $($sections -join ' ')"
Write-Host "+-------------------------------------+"

if ($PhaseInstall) {
  Write-Host ""
  Write-Host "======================================"
  Write-Host "  INSTALL PHASE (system-level)"
  Write-Host "======================================"

  if ($SecBase)   { Install-Base }
  if ($SecVscode) { Install-Vscode }
  if ($SecClaude) { Install-Claude }
}

if ($PhaseConfigure) {
  Write-Host ""
  Write-Host "======================================"
  Write-Host "  CONFIGURE PHASE (user-level)"
  Write-Host "======================================"

  if ($SecBase)     { Configure-Base }
  if ($SecTerminal) { Configure-Terminal }
  if ($SecVscode)   { Configure-Vscode }
  if ($SecClaude)   { Configure-Claude }
}

Write-Host ""
Write-Head "Done"
Write-Host ""
Write-Ok "Bootstrap complete (phase: $($phases -join ' '), sections: $($sections -join ' '))"

} finally {
  Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}
