#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

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

# ─── 1. Import Terminal.app profile ───

head "Terminal.app Pro profile"

info "Importing Pro profile..."

python3 -c "
import plistlib, subprocess, os

with open('$SCRIPT_DIR/Pro.terminal', 'rb') as f:
    profile = plistlib.load(f)

prefs_file = os.path.expanduser('~/Library/Preferences/com.apple.Terminal.plist')
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
ok "Pro profile imported and set as default"

echo

# ─── 2. Shell prompt ───

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

echo
ok "Terminal setup complete! Open a new Terminal window to see changes."
