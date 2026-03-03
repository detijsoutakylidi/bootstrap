#!/usr/bin/env bash

#
# Unified macOS bootstrap.
#
# Installs system tools and configures user environment in one pass.
#
# Install from anywhere:
#   bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh)
#   bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --install
#   bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --configure
#
# Run specific sections:
#   bash bootstrap.sh --vscode                   # VS Code only (install + configure)
#   bash bootstrap.sh --configure --terminal     # configure terminal only
#   bash bootstrap.sh --install --base --vscode  # install base + vscode only
#
# Or run locally:
#   bash bootstrap/script/bootstrap.sh [--install | --configure] [--base] [--vscode] [--claude] [--terminal]
#

set -euo pipefail

# When piped via `curl | bash`, bash reads stdin incrementally — exec < /dev/tty
# would discard the unread portion of the script. Use `bash -c "$(curl ...)"` or
# `bash <(curl ...)` instead, so bash loads the full script into memory first.
# Then this redirect safely switches stdin to the terminal for interactive prompts.
if [[ ! -t 0 ]]; then
  exec < /dev/tty
fi

REPO_RAW_URL="https://raw.githubusercontent.com/detijsoutakylidi/bootstrap/main/bootstrap/script/config"

# Detect local config dir (works when run from repo checkout)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_CONFIG_DIR="$SCRIPT_DIR/config"

# Temp dir for downloaded config files — cleaned up on exit
TMPDIR_BOOTSTRAP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BOOTSTRAP"' EXIT

# Fetch a config file — local if available, otherwise download from GitHub
# Usage: config_path=$(fetch_config "vscode/settings.json")
fetch_config() {
  local subpath="$1"
  if [[ -n "$SCRIPT_DIR" && -f "$LOCAL_CONFIG_DIR/$subpath" ]]; then
    echo "$LOCAL_CONFIG_DIR/$subpath"
    return
  fi
  local dest="$TMPDIR_BOOTSTRAP/$subpath"
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL "$REPO_RAW_URL/$subpath" -o "$dest"; then
    echo "$dest"
  else
    echo ""
  fi
}

blue=$'\033[1;34m'
green=$'\033[1;32m'
yellow=$'\033[1;33m'
red=$'\033[1;31m'
reset=$'\033[0m'

info()  { echo "${blue}▸${reset} $1"; }
ok()    { echo "${green}✔${reset} $1"; }
skip()  { echo "${yellow}⊘${reset} $1"; }
fail()  { echo "${red}✘${reset} $1"; }
head()  { echo; echo "${reset}⎯ $1 ⎯${reset}"; }

# ─── Argument parsing ───────────────────────────────────────

PHASE_INSTALL=false
PHASE_CONFIGURE=false
SEC_BASE=false
SEC_VSCODE=false
SEC_CLAUDE=false
SEC_TERMINAL=false
SECTION_SPECIFIED=false
EXTENDED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)   PHASE_INSTALL=true ;;
    --configure) PHASE_CONFIGURE=true ;;
    --base)      SEC_BASE=true; SECTION_SPECIFIED=true ;;
    --vscode)    SEC_VSCODE=true; SECTION_SPECIFIED=true ;;
    --claude)    SEC_CLAUDE=true; SECTION_SPECIFIED=true ;;
    --terminal)  SEC_TERMINAL=true; SECTION_SPECIFIED=true ;;
    --extended)  EXTENDED=true ;;
    *)
      fail "Unknown option: $1"
      echo "Usage: bash bootstrap.sh [--install | --configure] [--base] [--vscode] [--claude] [--terminal] [--extended]"
      exit 1
      ;;
  esac
  shift
done

# Default: all sections when none specified
if ! $SECTION_SPECIFIED; then
  SEC_BASE=true; SEC_VSCODE=true; SEC_CLAUDE=true; SEC_TERMINAL=true
fi

# Default: auto-detect phase when neither specified
if ! $PHASE_INSTALL && ! $PHASE_CONFIGURE; then
  if dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
    PHASE_INSTALL=true
    PHASE_CONFIGURE=true
  else
    info "Non-admin user detected — running in configure-only mode."
    info "For system installs, run from an admin account: bash bootstrap.sh --install"
    echo
    PHASE_CONFIGURE=true
  fi
fi

do_install()   { $PHASE_INSTALL; }
do_configure() { $PHASE_CONFIGURE; }
do_base()      { $SEC_BASE; }
do_vscode()    { $SEC_VSCODE; }
do_claude()    { $SEC_CLAUDE; }
do_terminal()  { $SEC_TERMINAL; }

# ═══════════════════════════════════════════════════════════════
# INSTALL PHASE
# ═══════════════════════════════════════════════════════════════

install_devbase() {
  # ─── Xcode Command Line Tools ───
  head "Xcode Command Line Tools"

  if xcode-select -p &>/dev/null; then
    skip "Already installed: $(xcode-select -p)"
  else
    info "Installing Xcode Command Line Tools…"
    info "A macOS dialog will pop up — click Install and wait."
    xcode-select --install

    until xcode-select -p &>/dev/null; do
      sleep 5
    done
    ok "Xcode Command Line Tools installed"
  fi

  # ─── Rosetta 2 (Apple Silicon only) ───
  head "Rosetta 2"

  arch=$(uname -m)
  if [[ "$arch" != "arm64" ]]; then
    skip "Not Apple Silicon ($arch) — Rosetta not needed"
  elif /usr/bin/pgrep -q oahd; then
    skip "Already installed"
  else
    info "Installing Rosetta 2…"
    softwareupdate --install-rosetta --agree-to-license
    ok "Rosetta 2 installed"
  fi

  # ─── Homebrew ───
  head "Homebrew"

  if command -v brew &>/dev/null; then
    skip "Already installed: $(brew --version | head -1)"
  else
    info "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    ok "Homebrew installed"
  fi

  # ─── Git ───
  head "Git"

  if command -v git &>/dev/null; then
    skip "Already installed: $(git --version)"
  else
    info "Installing Git via Homebrew…"
    brew install git
    ok "Git installed"
  fi

  # ─── jq ───
  head "jq"

  if command -v jq &>/dev/null; then
    skip "Already installed: $(jq --version)"
  else
    info "Installing jq via Homebrew…"
    brew install jq
    ok "jq installed"
  fi

  # ─── ripgrep ───
  head "ripgrep"

  if command -v rg &>/dev/null; then
    skip "Already installed: $(rg --version | head -1)"
  else
    info "Installing ripgrep via Homebrew…"
    brew install ripgrep
    ok "ripgrep installed"
  fi

  # ─── GitHub CLI ───
  head "GitHub CLI"

  if command -v gh &>/dev/null; then
    skip "Already installed: $(gh --version | head -1)"
  else
    info "Installing GitHub CLI via Homebrew…"
    brew install gh
    ok "GitHub CLI installed"
  fi
}

install_vscode() {
  # ─── VS Code app ───
  head "VS Code"

  if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ] || command -v code &>/dev/null || brew list --cask visual-studio-code &>/dev/null 2>&1; then
    skip "VS Code already installed"
  else
    info "Installing VS Code…"
    brew install --cask visual-studio-code
    ok "VS Code installed"
  fi

  # ─── duti ───
  head "duti"

  if command -v duti &>/dev/null; then
    skip "Already installed"
  else
    info "Installing duti (for file associations)…"
    brew install duti
    ok "duti installed"
  fi
}

install_claude() {
  # ─── Claude Code ───
  head "Claude Code"

  if command -v claude &>/dev/null; then
    skip "Already installed: claude $(claude --version 2>/dev/null || echo '?')"
  else
    info "Installing Claude Code via native installer…"
    if curl -fsSL https://claude.ai/install.sh | bash; then
      ok "Claude Code installed"
    else
      fail "Claude Code install failed"
    fi
  fi

  # ─── Claude Desktop ───
  head "Claude Desktop"

  if [[ -d "/Applications/Claude.app" ]] || brew list --cask claude &>/dev/null 2>&1; then
    skip "Already installed: Claude.app"
  else
    info "Installing Claude Desktop via Homebrew…"
    if brew install --cask claude; then
      ok "Claude Desktop installed"
    else
      fail "Claude Desktop install failed"
    fi
  fi

  # ─── CodexBar ───
  head "CodexBar"

  if [[ -d "/Applications/CodexBar.app" ]] || brew list --cask codexbar &>/dev/null 2>&1; then
    skip "Already installed: CodexBar.app"
  else
    info "Tapping steipete/tap…"
    brew tap steipete/tap 2>/dev/null || true
    info "Installing CodexBar via Homebrew…"
    if brew install --cask steipete/tap/codexbar; then
      ok "CodexBar installed"
    else
      fail "CodexBar install failed"
    fi
  fi
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURE PHASE
# ═══════════════════════════════════════════════════════════════

configure_devbase() {
  head "Git global config"

  GITIGNORE_SRC="$(fetch_config "git/gitignore_global")"
  GITIGNORE_DST="$HOME/.gitignore_global"

  if [[ -z "$GITIGNORE_SRC" || ! -f "$GITIGNORE_SRC" ]]; then
    fail "gitignore_global not found (local or remote)"
  elif [[ ! -f "$GITIGNORE_DST" ]]; then
    cp "$GITIGNORE_SRC" "$GITIGNORE_DST"
    git config --global core.excludesFile "$GITIGNORE_DST"
    ok "Global gitignore installed → $GITIGNORE_DST"
  elif diff -q "$GITIGNORE_SRC" "$GITIGNORE_DST" &>/dev/null; then
    git config --global core.excludesFile "$GITIGNORE_DST"
    skip "Global gitignore already up to date"
  else
    info "Current ~/.gitignore_global:"
    sed 's/^/    /' "$GITIGNORE_DST"
    echo
    info "New gitignore_global from setup:"
    sed 's/^/    /' "$GITIGNORE_SRC"
    echo
    read -rp "$(echo "${blue}▸${reset} [S]kip / [O]verwrite / [M]erge entry by entry? [s/o/m] ")" choice
    case "$choice" in
      [oO])
        cp "$GITIGNORE_SRC" "$GITIGNORE_DST"
        ok "Global gitignore overwritten"
        ;;
      [mM])
        mapfile -t all_entries < <(cat "$GITIGNORE_DST" "$GITIGNORE_SRC" | grep -v '^$' | sort -u)
        mapfile -t current < <(grep -v '^$' "$GITIGNORE_DST" 2>/dev/null || true)
        MERGED=()
        for entry in "${all_entries[@]}"; do
          in_current=false
          in_new=false
          for c in "${current[@]}"; do [[ "$c" == "$entry" ]] && in_current=true && break; done
          while IFS= read -r n; do [[ "$n" == "$entry" ]] && in_new=true && break; done < <(grep -v '^$' "$GITIGNORE_SRC")
          if $in_current && $in_new; then
            MERGED+=("$entry")
            skip "Keep: $entry (in both)"
          elif $in_current; then
            read -rp "$(echo "${blue}▸${reset} Keep \"$entry\" (only in current)? [Y/n] ")" ans
            [[ ! "$ans" =~ ^[Nn]$ ]] && MERGED+=("$entry")
          else
            read -rp "$(echo "${blue}▸${reset} Add \"$entry\" (new from setup)? [Y/n] ")" ans
            [[ ! "$ans" =~ ^[Nn]$ ]] && MERGED+=("$entry")
          fi
        done
        printf '%s\n' "${MERGED[@]}" > "$GITIGNORE_DST"
        ok "Global gitignore merged"
        ;;
      *)
        skip "Kept existing global gitignore"
        ;;
    esac
    git config --global core.excludesFile "$GITIGNORE_DST"
  fi
}

configure_terminal() {
  # ─── Terminal.app Pro profile ───
  head "Terminal.app Pro profile"

  PRO_TERMINAL="$(fetch_config "terminal/Pro.terminal")"
  if [[ -z "$PRO_TERMINAL" || ! -f "$PRO_TERMINAL" ]]; then
    fail "Pro.terminal not found (local or remote)"
    return
  fi

  PROFILE_CHANGED=$(python3 -c "
import plistlib, subprocess, sys

with open('$PRO_TERMINAL', 'rb') as f:
    new_profile = plistlib.load(f)

try:
    result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
    prefs = plistlib.loads(result.stdout)
    current_profile = prefs.get('Window Settings', {}).get('Pro')
except:
    current_profile = None

if current_profile is None:
    print('new')
elif current_profile == new_profile:
    print('same')
else:
    print('different')
")

  import_profile() {
    python3 -c "
import plistlib, subprocess, os

with open('$PRO_TERMINAL', 'rb') as f:
    profile = plistlib.load(f)

try:
    result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
    prefs = plistlib.loads(result.stdout)
except:
    prefs = {}

if 'Window Settings' not in prefs:
    prefs['Window Settings'] = {}
prefs['Window Settings']['Pro'] = profile

with open('/tmp/terminal-import.plist', 'wb') as f:
    plistlib.dump(prefs, f)
subprocess.run(['defaults', 'import', 'com.apple.Terminal', '/tmp/terminal-import.plist'], check=True)
os.remove('/tmp/terminal-import.plist')
"
    defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  }

  case "$PROFILE_CHANGED" in
    new)
      info "Importing Pro profile..."
      import_profile
      ok "Pro profile imported and set as default"
      ;;
    same)
      skip "Pro profile already up to date"
      ;;
    different)
      info "Pro profile differs from setup version."
      read -rp "$(echo "${blue}▸${reset} [S]kip / [O]verwrite? [s/o] ")" choice
      case "$choice" in
        [oO])
          import_profile
          ok "Pro profile overwritten"
          ;;
        *)
          skip "Kept existing Pro profile"
          ;;
      esac
      ;;
  esac

  # ─── Shell prompt ───
  head "Shell prompt"

  SHELL_RC="$HOME/.zshrc"
  PROMPT_LINE="PROMPT='%1~ % '"

  if grep -q "^PROMPT=" "$SHELL_RC" 2>/dev/null; then
    CURRENT=$(grep "^PROMPT=" "$SHELL_RC")
    if [ "$CURRENT" = "$PROMPT_LINE" ]; then
      skip "Prompt already set"
    else
      info "Prompt already configured as: $CURRENT"
      read -rp "$(echo "${blue}▸${reset} Replace with: $PROMPT_LINE? [y/N] ")" answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        sed -i '' "s|^PROMPT=.*|$PROMPT_LINE|" "$SHELL_RC"
        ok "Prompt updated"
      else
        skip "Kept existing prompt"
      fi
    fi
  else
    echo '' >> "$SHELL_RC"
    echo '# prompt' >> "$SHELL_RC"
    echo "$PROMPT_LINE" >> "$SHELL_RC"
    ok "Prompt added to ~/.zshrc"
  fi
}

configure_vscode() {
  VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"

  # ─── code CLI in PATH ───
  head "VS Code CLI"

  VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  if command -v code &>/dev/null; then
    skip "'code' already in PATH"
  elif [ -d "$VSCODE_BIN" ]; then
    export PATH="$PATH:$VSCODE_BIN"

    SHELL_RC="$HOME/.zshrc"
    if ! grep -q "Visual Studio Code" "$SHELL_RC" 2>/dev/null; then
      echo '' >> "$SHELL_RC"
      echo '# VS Code CLI' >> "$SHELL_RC"
      echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> "$SHELL_RC"
      ok "'code' added to PATH permanently (~/.zshrc)"
    fi
  else
    fail "VS Code not found — install it first (bash bootstrap.sh --install)"
    return
  fi

  # ─── Projects directory ───
  head "Projects directory"

  read -rp "$(echo "${blue}▸${reset} Projects directory (default: ~/Projects): ")" PROJECTS_DIR
  PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"
  PROJECTS_DIR="${PROJECTS_DIR/#\~/$HOME}"

  if [ -d "$PROJECTS_DIR" ]; then
    skip "Projects directory exists: $PROJECTS_DIR"
  else
    info "Creating $PROJECTS_DIR..."
    mkdir -p "$PROJECTS_DIR"
    ok "Created $PROJECTS_DIR"
  fi

  # ─── Essential extensions ───
  head "Essential extensions"

  INSTALLED_EXTENSIONS=$(code --list-extensions 2>/dev/null || true)

  install_extension() {
    local ext="$1"
    local name="$2"
    if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext}$"; then
      skip "$name already installed"
    else
      info "Installing $name..."
      code --install-extension "$ext" --force
      ok "$name installed"
    fi
  }

  install_extension "anthropic.claude-code"           "Claude Code"
  install_extension "catppuccin.catppuccin-vsc"       "Catppuccin Theme"
  install_extension "alefragnani.project-manager"     "Project Manager"
  install_extension "mrmlnc.vscode-duplicate"         "Duplicate Action"
  install_extension "natizyskunk.sftp"                "SFTP"
  install_extension "johnpapa.vscode-peacock"          "Peacock"
  install_extension "zaaack.markdown-editor"           "Markdown Editor"

  # ─── Optional extensions (--extended) ───
  if $EXTENDED; then
    head "Optional extensions"

    ask_install() {
      local ext="$1"
      local name="$2"
      if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext}$"; then
        skip "$name already installed"
        return
      fi
      read -rp "$(echo "${blue}▸${reset} Install $name? [y/N] ")" answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        code --install-extension "$ext" --force
        ok "$name installed"
      fi
    }

    ask_install "bmewburn.vscode-intelephense-client"   "Intelephense (PHP)"
    ask_install "britesnow.vscode-toggle-quotes"         "Toggle Quotes"
    ask_install "hashicorp.terraform"                    "Terraform"
    ask_install "highagency.pencildev"                   "Pencil"
  fi

  # ─── Config files ───
  head "Config files"

  mkdir -p "$VSCODE_CONFIG_DIR"

  install_config() {
    local src_content="$1"
    local dst="$2"
    local label="$3"

    if [[ ! -f "$dst" ]]; then
      echo "$src_content" > "$dst"
      ok "$label installed"
    elif diff -q <(echo "$src_content") "$dst" &>/dev/null; then
      skip "$label already up to date"
    else
      info "$label differs from setup version:"
      diff --unified=3 "$dst" <(echo "$src_content") | head -40 || true
      echo
      read -rp "$(echo "${blue}▸${reset} [S]kip / [O]verwrite? [s/o] ")" choice
      case "$choice" in
        [oO])
          echo "$src_content" > "$dst"
          ok "$label overwritten"
          ;;
        *)
          skip "Kept existing $label"
          ;;
      esac
    fi
  }

  SETTINGS_SRC="$(fetch_config "vscode/settings.json")"
  if [[ -n "$SETTINGS_SRC" && -f "$SETTINGS_SRC" ]]; then
    RENDERED_SETTINGS=$(sed -e "s|__HOME__|$HOME|g" \
        -e "s|__PROJECTS_DIR__|$PROJECTS_DIR|g" \
        "$SETTINGS_SRC")
    install_config "$RENDERED_SETTINGS" "$VSCODE_CONFIG_DIR/settings.json" "settings.json"
  else
    fail "settings.json not found (local or remote)"
  fi

  KEYBINDINGS_SRC="$(fetch_config "vscode/keybindings.json")"
  if [[ -n "$KEYBINDINGS_SRC" && -f "$KEYBINDINGS_SRC" ]]; then
    KEYBINDINGS_CONTENT=$(cat "$KEYBINDINGS_SRC")
    install_config "$KEYBINDINGS_CONTENT" "$VSCODE_CONFIG_DIR/keybindings.json" "keybindings.json"
  else
    fail "keybindings.json not found (local or remote)"
  fi

  # ─── File associations ───
  head "File associations"

  if ! command -v duti &>/dev/null; then
    fail "duti not found — install it first (bash bootstrap.sh --install)"
  else
    VSCODE_BUNDLE="com.microsoft.VSCode"

    set_file_association() {
      local identifier="$1"
      local label="$2"
      local type="$3"

      local current=""
      if [ "$type" = "ext" ]; then
        current=$(duti -x "${identifier#.}" 2>/dev/null | head -1 || true)
      else
        current=$(duti -d "$identifier" 2>/dev/null | head -1 || true)
      fi

      if echo "$current" | grep -qi "Visual Studio Code"; then
        skip "$label already opens in VS Code"
        return
      fi

      if [ -n "$current" ] && [ "$current" != "null" ]; then
        read -rp "$(echo "${blue}▸${reset} $label currently opens in: $current. Set to VS Code? [y/N] ")" answer
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
          return
        fi
      fi

      duti -s "$VSCODE_BUNDLE" "$identifier" all
      ok "$label → VS Code"
    }

    # UTI-based associations
    set_file_association "public.json"                    ".json"       "uti"
    set_file_association "public.xml"                     ".xml"        "uti"
    set_file_association "com.netscape.javascript-source" ".js"         "uti"
    set_file_association "org.w3.webvtt"                  ".vtt"        "uti"

    # Extension-based associations
    set_file_association ".md"       ".md"       "ext"
    set_file_association ".jsonl"    ".jsonl"    "ext"
    set_file_association ".srt"      ".srt"      "ext"
    set_file_association ".pub"      ".pub"      "ext"
    set_file_association ".tf"       ".tf"       "ext"
    set_file_association ".tfstate"  ".tfstate"  "ext"
  fi
}

configure_claude() {
  head "Claude ecosystem"

  # ─── Chrome extension ───
  info "Opening Chrome Web Store for Claude in Chrome…"
  open 'https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn' 2>/dev/null || true
  ok "Chrome Web Store opened — install manually"

  # ─── Manual steps ───
  head "Manual steps needed"
  echo
  info "Run: claude login                       → authenticate Claude Code"
  info "Run: gh auth login                      → authenticate GitHub CLI"
  info "Open Claude.app                         → sign in with your account"
  info "Open CodexBar                           → enable Claude provider in Settings → Providers"
  info "Chrome Web Store                        → click \"Add to Chrome\" if not done"
  info "Claude Desktop → Settings → Connectors  → enable Claude in Chrome connector"
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

PHASES=""
$PHASE_INSTALL && PHASES="${PHASES}install "
$PHASE_CONFIGURE && PHASES="${PHASES}configure "
SECTIONS=""
$SEC_BASE && SECTIONS="${SECTIONS}base "
$SEC_VSCODE && SECTIONS="${SECTIONS}vscode "
$SEC_CLAUDE && SECTIONS="${SECTIONS}claude "
$SEC_TERMINAL && SECTIONS="${SECTIONS}terminal "

echo
echo "┌─────────────────────────────────────┐"
echo "│  macOS Bootstrap"
echo "│  phase: ${PHASES% }"
echo "│  sections: ${SECTIONS% }"
echo "└─────────────────────────────────────┘"

if do_install; then
  echo
  echo "══════════════════════════════════════"
  echo "  INSTALL PHASE (system-level)"
  echo "══════════════════════════════════════"

  if do_base;   then install_devbase; fi
  if do_vscode; then install_vscode; fi
  if do_claude; then install_claude; fi
fi

if do_configure; then
  echo
  echo "══════════════════════════════════════"
  echo "  CONFIGURE PHASE (user-level)"
  echo "══════════════════════════════════════"

  if do_base;     then configure_devbase;  fi
  if do_terminal; then configure_terminal; fi
  if do_vscode;   then configure_vscode;   fi
  if do_claude;   then configure_claude;   fi
fi

echo
head "Done"
echo
ok "Bootstrap complete (phase: ${PHASES% }, sections: ${SECTIONS% })"
