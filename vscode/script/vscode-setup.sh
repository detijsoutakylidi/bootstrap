#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"

blue=$'\033[1;34m'
green=$'\033[1;32m'
yellow=$'\033[1;33m'
red=$'\033[1;31m'
reset=$'\033[0m'

info()  { echo "${blue}▸${reset} $1"; }
ok()    { echo "${green}✔${reset} $1"; }
skip()  { echo "${yellow}⊘${reset} $1"; }
fail()  { echo "${red}✘${reset} $1"; }
head()  { echo "${reset}⎯ $1 ⎯${reset}"; }

# ─── Preflight: Homebrew must exist (installed by devbase-setup.sh) ─

if ! command -v brew &>/dev/null; then
  fail "Homebrew not found. Run devbase-setup.sh first."
  exit 1
fi

# ─── 1. VS Code ───

head "VS Code"

if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ] || command -v code &>/dev/null || brew list --cask visual-studio-code &>/dev/null; then
  skip "VS Code already installed"
else
  info "Installing VS Code..."
  brew install --cask visual-studio-code
  ok "VS Code installed"
fi

# Ensure `code` CLI is available (now and permanently)
VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
if ! command -v code &>/dev/null && [ -d "$VSCODE_BIN" ]; then
  export PATH="$PATH:$VSCODE_BIN"

  SHELL_RC="$HOME/.zshrc"
  if ! grep -q "Visual Studio Code" "$SHELL_RC" 2>/dev/null; then
    echo '' >> "$SHELL_RC"
    echo '# VS Code CLI' >> "$SHELL_RC"
    echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> "$SHELL_RC"
    ok "'code' added to PATH permanently (~/.zshrc)"
  fi
fi

echo

# ─── 2. Projects directory ───

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

echo

# ─── 3. Essential extensions ───

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

echo

# ─── 4. Optional extensions ───

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
ask_install "mehedidracula.php-namespace-resolver"   "PHP Namespace Resolver"
ask_install "britesnow.vscode-toggle-quotes"         "Toggle Quotes"
ask_install "hashicorp.terraform"                    "Terraform"

echo

# ─── 5. Config files ───

head "Config files"

mkdir -p "$VSCODE_CONFIG_DIR"

sed -e "s|__HOME__|$HOME|g" \
    -e "s|__PROJECTS_DIR__|$PROJECTS_DIR|g" \
    "$SCRIPT_DIR/settings.json" > "$VSCODE_CONFIG_DIR/settings.json"
ok "settings.json installed"

cp "$SCRIPT_DIR/keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"
ok "keybindings.json installed"

echo

# ─── 6. File associations ───

head "File associations"

if ! command -v duti &>/dev/null; then
  info "Installing duti (for file associations)..."
  brew install duti
  ok "duti installed"
fi

VSCODE_BUNDLE="com.microsoft.VSCode"

set_file_association() {
  local identifier="$1"
  local label="$2"
  local type="$3"  # "uti" or "ext"

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

echo
ok "VS Code setup complete!"
