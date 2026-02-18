# Claude Setup — Creation Playbook

How this setup script was created. See `vscode/create.md` for the general template.

## What was gathered

1. Claude ecosystem tools currently in use: Claude Code, Claude Desktop, CodexBar, Claude in Chrome
2. Install methods for each (native installer, brew cask, brew tap, Chrome Web Store)
3. Manual post-install steps (login, provider config, connector setup)

## Decisions

- **Prerequisites**: Requires Homebrew from devbase-setup.sh — exits with error if missing
- **No config files**: Pure install script — Claude Code config lives in `~/.claude/` and is managed separately
- **Summary table**: Uses indexed arrays (not associative) for bash 3.2 compatibility on stock macOS
- **Chrome extension**: Opens Web Store page — no way to automate Chrome extension install
- **Idempotent**: Each step checks if already installed and skips
