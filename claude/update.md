# Claude Setup — Update Playbook

Instructions for Claude Code to follow when updating the Claude ecosystem setup script.

## When to Use

Run this workflow when asked to sync/update the Claude setup script, typically when new Claude ecosystem tools should be added or install methods have changed.

## Steps

### 1. Review Claude ecosystem tools

1. Check what Claude-related apps are installed on the machine:
   - `command -v claude` — Claude Code
   - `ls /Applications/Claude.app` — Claude Desktop
   - `ls /Applications/CodexBar.app` — CodexBar
   - Check Chrome extensions manually
2. Compare against the tools in `claude/script/claude-setup.sh`
3. Ask the user if any new tools should be added or existing ones removed

### 2. Check install methods

1. Verify Claude Code native installer URL is still current
2. Verify brew cask names haven't changed (`claude`, `steipete/tap/codexbar`)
3. Verify Chrome Web Store extension URL is still valid

### 3. Review manual steps

1. Check if any manual steps can now be automated
2. Update the manual steps list if post-install flow has changed

### 4. Finalize

- Ask whether to commit the changes
