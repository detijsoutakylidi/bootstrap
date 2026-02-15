#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ─── Colors ───
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[info]${NC} $1"; }
ok()    { echo -e "${GREEN}[ok]${NC} $1"; }
ask()   { echo -e "${YELLOW}[?]${NC} $1"; }

# ─── 1. Import Terminal.app profile ───
info "Importing Terminal.app Pro profile..."

# Merge our Pro profile settings into Terminal's preferences
# plutil converts the .terminal plist into Terminal's Window Settings dict
python3 -c "
import plistlib, subprocess, os

# Read our profile
with open('$SCRIPT_DIR/Pro.terminal', 'rb') as f:
    profile = plistlib.load(f)

# Read current Terminal prefs
prefs_file = os.path.expanduser('~/Library/Preferences/com.apple.Terminal.plist')
try:
    result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
    prefs = plistlib.loads(result.stdout)
except:
    prefs = {}

# Update the Pro profile in Window Settings
if 'Window Settings' not in prefs:
    prefs['Window Settings'] = {}
prefs['Window Settings']['Pro'] = profile

# Write back
with open('/tmp/terminal-import.plist', 'wb') as f:
    plistlib.dump(prefs, f)
subprocess.run(['defaults', 'import', 'com.apple.Terminal', '/tmp/terminal-import.plist'], check=True)
os.remove('/tmp/terminal-import.plist')
"

# Set as default and startup profile
defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
ok "Pro profile imported and set as default"

# ─── 2. Shell prompt ───
SHELL_RC="$HOME/.zshrc"
PROMPT_LINE="PROMPT='%1~ % '"

if grep -q "^PROMPT=" "$SHELL_RC" 2>/dev/null; then
  CURRENT=$(grep "^PROMPT=" "$SHELL_RC")
  if [ "$CURRENT" = "$PROMPT_LINE" ]; then
    ok "Prompt already set"
  else
    ask "Prompt already configured as: $CURRENT"
    ask "Replace with: $PROMPT_LINE? [y/N] "
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      sed -i '' "s|^PROMPT=.*|$PROMPT_LINE|" "$SHELL_RC"
      ok "Prompt updated"
    fi
  fi
else
  echo '' >> "$SHELL_RC"
  echo '# prompt' >> "$SHELL_RC"
  echo "$PROMPT_LINE" >> "$SHELL_RC"
  ok "Prompt added to ~/.zshrc"
fi

echo ""
ok "Terminal setup complete! Open a new Terminal window to see changes."
