# setup

Project for creating and updating setup scripts

## Structure

Each setup script lives in its own folder with a standard structure:

```
<tool>/
├── create.md              # How the script was created (template for new scripts)
├── update.md              # Claude playbook for syncing script with live config
└── script/
    ├── <tool>-setup.sh    # macOS setup script (run with: bash <tool>/script/<tool>-setup.sh)
    ├── <tool>-setup-win.ps1  # Windows setup script (run in PowerShell)
    └── <config-files>     # Config files, using placeholders for machine-specific values
```

- **create.md** — documents how the script was built, use as a template when creating new setup scripts
- **update.md** — instructions for Claude to follow when syncing the script with the current machine's config. Starts with an optional revision step (cleanup + reorganize), then diffs extensions, settings, and keybindings
- **script/** — the setup script and its config file dependencies. Config files use placeholders (e.g. `__HOME__`, `__PROJECTS_DIR__`) that get substituted at runtime

### Run order

**macOS:** `bash <tool>/script/<tool>-setup.sh`
**Windows:** run `.\<tool>-setup-win.ps1` in PowerShell

1. `devbase` — system prerequisites (macOS: Xcode CLT, Homebrew; Windows: winget, Git)
2. `claude`, `vscode`, `terminal` — independent, any order after devbase

### Current scripts

```
devbase/                           # Run first — base system prerequisites
├── create.md
├── update.md
└── script/
    ├── devbase-setup.sh
    └── devbase-setup-win.ps1

claude/                            # Claude ecosystem (Code, Desktop, CodexBar)
├── create.md
├── update.md
└── script/
    ├── claude-setup.sh
    └── claude-setup-win.ps1

vscode/
├── create.md
├── update.md
└── script/
    ├── vscode-setup.sh
    ├── vscode-setup-win.ps1
    ├── settings.json              # Shared (macOS + Windows, placeholders substituted at runtime)
    ├── keybindings.json           # macOS (cmd-based)
    └── keybindings-win.json       # Windows (ctrl-based)

terminal/
├── create.md
├── update.md
└── script/
    ├── terminal-setup.sh
    ├── terminal-setup-win.ps1
    ├── Pro.terminal               # macOS Terminal.app profile
    └── windows-terminal-profile.json  # Windows Terminal color scheme + defaults

claude-code-session-sync/          # Standalone utility, no update.md
├── create.md
├── initial-prompt.md
└── script/
    └── claude-code-session-sync.php   # Run with: php claude-code-session-sync/script/claude-code-session-sync.php
```

## Notes

- **This repo is public.** Never commit secrets, tokens, API keys, passwords, or machine-specific paths. Config files must use placeholders (`__HOME__`, etc.) — verify before every commit.
