# Bootstrap — Update Playbook

Instructions for Claude Code to follow when syncing the bootstrap scripts with the current machine's config.

## When to Use

Run this workflow when asked to sync/update the bootstrap scripts, typically after changing VS Code config, terminal settings, extensions, or packages on the live machine.

## Step 0. Offer Config Revision

Before syncing, ask the user if they want to clean up their live VS Code config. If yes:

### 0a. Clean up orphaned extension references

1. Run `code --list-extensions` to get installed extensions
2. Scan live `settings.json` for settings from uninstalled extensions
3. Scan live `keybindings.json` for bindings from uninstalled extensions
4. Present findings, remove confirmed orphans

### 0b. Reorganize settings

1. Check if `settings.json` has settings outside their logical group
2. Reorganize into groups with comment headers: `// group name — description`
3. Groups: window, workbench, explorer & search, problems, editor (appearance, minimap, brackets, suggestions), silence the noise, diff editor, scm & git, files, terminal, security & telemetry, PHP, extension-specific
4. Show proposed reorganization before applying

### 0c. Reorganize keybindings

1. Check if `keybindings.json` has bindings outside their logical group
2. Reorganize with comment headers and per-binding comments
3. Groups: panels, explorer, code navigation, editing, terminal, extension-specific
4. Show proposed reorganization before applying

**Back up files before revision changes (copy to `.bak`).**

## macOS Steps

### 1. Compare brew packages

1. Run `brew list` and compare against install functions in `bootstrap.sh`
2. Ask if any new packages should be added (and whether to install phase or a specific tool's section)

### 2. Compare VS Code extensions

1. Run `code --list-extensions` and compare against essential + optional lists in `configure_vscode()`
2. Present table: in script but not installed (remove?), installed but not in script (add?)
3. Ask for each diff: add to essential, optional, or skip
4. **Update both `bootstrap.sh` and `bootstrap.ps1`** extension lists to keep them in sync

### 3. Compare VS Code settings

1. Read live `~/Library/Application Support/Code/User/settings.json`
2. Diff against `bootstrap/script/config/vscode/settings.json` (substitute `__HOME__` and `__PROJECTS_DIR__` for comparison)
3. Show meaningful diffs, update stored file with approved changes, re-apply placeholders

### 4. Compare VS Code keybindings

1. Read live `~/Library/Application Support/Code/User/keybindings.json`
2. Diff against `bootstrap/script/config/vscode/keybindings.json`
3. Show diffs, update with approved changes
4. Ask whether changes also apply to `keybindings-win.json` (often yes for non-modifier changes)

### 5. Compare Terminal.app profile

1. Export current Pro profile via `defaults export com.apple.Terminal` + plistlib
2. Compare against `bootstrap/script/config/terminal/Pro.terminal`
3. Show diffs, update stored profile with approved changes

### 6. Compare shell prompt

1. Read `~/.zshrc` PROMPT= line
2. Compare against the prompt in `configure_terminal()` in `bootstrap.sh`
3. If different, ask whether to update

### 7. Compare global gitignore

1. Diff `bootstrap/script/config/git/gitignore_global` against `~/.gitignore_global`
2. Ask if entries should be added or removed

### 8. Compare CodexBar config

1. Diff `~/.codexbar/config.json` against `bootstrap/script/config/codexbar/config.json`
2. Show diffs, update stored file with approved changes
3. Export current preferences: `defaults export com.steipete.codexbar /tmp/codexbar-current.plist`
4. Compare against `bootstrap/script/config/codexbar/defaults.plist` — ignore machine-specific keys (keychain fingerprints, OAuth timestamps, window frames, NSStatusItem positions, Sparkle update state)
5. Show meaningful diffs, update stored plist with approved changes

### 9. Check install methods

1. Verify Homebrew install URL is current
2. Verify Claude Code native installer URL works (`https://claude.ai/install.sh` for macOS, `https://claude.ai/install.ps1` for Windows)
3. Verify brew cask names haven't changed (`visual-studio-code`, `claude`, `steipete/tap/codexbar`)
4. Verify winget IDs haven't changed (`Microsoft.VisualStudioCode`, `Anthropic.Claude`, `Git.Git`, etc.)
5. Verify Chrome Web Store extension URL is valid

### 10. Finalize

- Verify `config/vscode/settings.json` still has `__HOME__` and `__PROJECTS_DIR__` placeholders
- Verify `bootstrap.ps1` extension lists match `bootstrap.sh`
- Ask whether to commit the changes

## Windows-Specific Steps

When syncing from a Windows machine (or asked to update the Windows script specifically):

### W1. Compare winget packages

1. Compare against Install-Base in `bootstrap.ps1`
2. Ask if any new packages should be added

### W2. Compare Windows Terminal profile

1. Read live Windows Terminal `settings.json`
2. Compare against `bootstrap/script/config/terminal/windows-terminal-profile.json`
3. Show diffs in color scheme and profile defaults

### W3. Compare PowerShell prompt

1. Read `$PROFILE.CurrentUserAllHosts`
2. Compare against the prompt block in `Configure-Terminal` in `bootstrap.ps1`

### W4. Compare file associations

1. Check current file associations for the 10 extensions
2. Compare against the list in `Install-Vscode` in `bootstrap.ps1`
