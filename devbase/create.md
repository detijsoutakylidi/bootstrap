# Devbase Setup — Creation Playbook

How this setup script was created. See `vscode/create.md` for the general template.

## What was gathered

1. Essential CLI tools needed before any other setup script runs
2. Xcode CLT, Rosetta 2, Homebrew as foundation
3. Common brew packages used across scripts: jq, ripgrep, gh

## Decisions

- **Run order**: This script runs first, before claude/vscode/terminal scripts
- **Scope**: Only system-level prerequisites and common CLI tools — no app-specific config
- **Idempotent**: Each step checks if already installed and skips with a message
- **No config files**: Pure install script, no SCRIPT_DIR needed
- **No interactive prompts**: Everything installs without user input (except Xcode CLT macOS dialog)
