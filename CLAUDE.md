# setup

Project for creating and updating setup scripts

## Structure

```
bootstrap/                         # Unified setup — one script per platform
├── create.md                      # How the scripts were created
├── update.md                      # Claude playbook for syncing with live config
└── script/
    ├── bootstrap.sh               # macOS: bash <(curl -fsSL <raw-url>)
    ├── bootstrap.ps1              # Windows: irm <raw-url> | iex
    └── config/
        ├── git/
        │   └── gitignore_global
        ├── terminal/
        │   ├── Pro.terminal                    # macOS Terminal.app profile
        │   └── windows-terminal-profile.json   # Windows Terminal color scheme + defaults
        └── vscode/
            ├── settings.json          # Shared (placeholders substituted at runtime)
            ├── keybindings.json       # macOS (cmd-based)
            └── keybindings-win.json   # Windows (ctrl-based)

claude-code-session-sync/          # Standalone utility, no update.md
├── create.md
├── initial-prompt.md
└── script/
    └── claude-code-session-sync.php
```

### Run

**macOS:** `bash bootstrap/script/bootstrap.sh [--install | --configure] [--base] [--vscode] [--claude] [--terminal]`
**Windows:** `.\bootstrap\script\bootstrap.ps1 [--install | --configure] [--base] [--vscode] [--claude] [--terminal]`

Both scripts auto-detect admin status, are idempotent, and support cloud install (see README).

- **create.md** — documents how the scripts were built, use as a template when adding new tools
- **update.md** — instructions for Claude to follow when syncing the scripts with the current machine's config
- **config/** — config files with placeholders (`__HOME__`, `__PROJECTS_DIR__`) substituted at runtime

## Notes

- **This repo is public.** Never commit secrets, tokens, API keys, passwords, or machine-specific paths. Config files must use placeholders (`__HOME__`, etc.) — verify before every commit.
