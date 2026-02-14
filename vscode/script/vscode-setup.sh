#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"

# ─── Colors ───
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
ask()   { echo -e "${YELLOW}[?]${NC} $1"; }

# ─── 1. Homebrew ───
if command -v brew &>/dev/null; then
  ok "Homebrew already installed"
else
  info "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ok "Homebrew installed"
fi

# ─── 2. VS Code ───
if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ] || command -v code &>/dev/null || brew list --cask visual-studio-code &>/dev/null; then
  ok "VS Code already installed"
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

# ─── 3. Projects directory ───
ask "Projects directory (default: ~/Projects):"
read -r PROJECTS_DIR
PROJECTS_DIR="${PROJECTS_DIR:-$HOME/Projects}"

# Expand ~ if user typed it
PROJECTS_DIR="${PROJECTS_DIR/#\~/$HOME}"

if [ -d "$PROJECTS_DIR" ]; then
  ok "Projects directory exists: $PROJECTS_DIR"
else
  info "Creating $PROJECTS_DIR..."
  mkdir -p "$PROJECTS_DIR"
  ok "Created $PROJECTS_DIR"
fi

# ─── 4. Essential extensions ───
info "Installing essential extensions..."

INSTALLED_EXTENSIONS=$(code --list-extensions 2>/dev/null || true)

install_extension() {
  local ext="$1"
  local name="$2"
  if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext}$"; then
    ok "$name already installed"
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

# ─── 5. Optional extensions ───
info "Optional extensions..."

ask_install() {
  local ext="$1"
  local name="$2"
  if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext}$"; then
    ok "$name already installed"
    return
  fi
  ask "Install $name? [y/N] "
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    code --install-extension "$ext" --force
    ok "$name installed"
  fi
}

ask_install "bmewburn.vscode-intelephense-client"   "Intelephense (PHP)"
ask_install "mehedidracula.php-namespace-resolver"   "PHP Namespace Resolver"
ask_install "britesnow.vscode-toggle-quotes"         "Toggle Quotes"
ask_install "hashicorp.terraform"                    "Terraform"

# ─── 6. Config files ───
info "Copying config files..."

mkdir -p "$VSCODE_CONFIG_DIR"

# settings.json — substitute placeholders
sed -e "s|__HOME__|$HOME|g" \
    -e "s|__PROJECTS_DIR__|$PROJECTS_DIR|g" \
    "$SCRIPT_DIR/settings.json" > "$VSCODE_CONFIG_DIR/settings.json"
ok "settings.json installed"

# keybindings.json — copy as-is
cp "$SCRIPT_DIR/keybindings.json" "$VSCODE_CONFIG_DIR/keybindings.json"
ok "keybindings.json installed"

# ─── 7. File associations ───
if ! command -v duti &>/dev/null; then
  info "Installing duti (for file associations)..."
  brew install duti
  ok "duti installed"
fi

info "Setting file associations..."

VSCODE_BUNDLE="com.microsoft.VSCode"

set_file_association() {
  local identifier="$1"
  local label="$2"
  local type="$3"  # "uti" or "ext"

  # Check current handler
  local current=""
  if [ "$type" = "ext" ]; then
    current=$(duti -x "${identifier#.}" 2>/dev/null | head -1 || true)
  else
    current=$(duti -d "$identifier" 2>/dev/null | head -1 || true)
  fi

  # Already set to VS Code
  if echo "$current" | grep -qi "Visual Studio Code"; then
    ok "$label already opens in VS Code"
    return
  fi

  # Another app is set — ask before overwriting
  if [ -n "$current" ] && [ "$current" != "null" ]; then
    ask "$label currently opens in: $current. Set to VS Code? [y/N] "
    read -r answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
      return
    fi
  fi

  if [ "$type" = "ext" ]; then
    duti -s "$VSCODE_BUNDLE" "$identifier" all
  else
    duti -s "$VSCODE_BUNDLE" "$identifier" all
  fi
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

echo ""
ok "VS Code setup complete!"
