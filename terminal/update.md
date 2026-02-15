# Terminal Setup — Update Playbook

Instructions for Claude Code to follow when updating the terminal setup script from the current machine's config.

## When to Use

Run this workflow when asked to sync/update the terminal setup script with the current machine's config.

## Steps

### 1. Compare Terminal.app Profile

1. Export the current Pro profile:
   ```python
   import plistlib
   with open('/tmp/terminal-prefs.plist', 'rb') as f:
       data = plistlib.load(f)
   pro = data['Window Settings']['Pro']
   ```
   (First run `defaults export com.apple.Terminal /tmp/terminal-prefs.plist`)

2. Compare keys/values against the stored `terminal/script/Pro.terminal`
3. Show diffs to the user, update stored profile with approved changes

### 2. Compare Shell Prompt

1. Read `~/.zshrc` and find the `PROMPT=` line
2. Compare against the prompt line in `terminal/script/terminal-setup.sh`
3. If different, show diff and ask whether to update

### 3. Finalize

- Ask whether to commit the changes
