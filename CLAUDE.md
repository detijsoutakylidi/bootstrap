# setup

Project for creating and updating setup scripts

## Structure

Each setup script lives in its own folder with a standard structure:

```
<tool>/
├── create.md              # How the script was created (template for new scripts)
├── update.md              # Claude playbook for syncing script with live config
└── script/
    ├── <tool>-setup.sh    # Main setup script (run with: bash <tool>/script/<tool>-setup.sh)
    └── <config-files>     # Config files, using placeholders for machine-specific values
```

- **create.md** — documents how the script was built, use as a template when creating new setup scripts
- **update.md** — instructions for Claude to follow when syncing the script with the current machine's config. Starts with an optional revision step (cleanup + reorganize), then diffs extensions, settings, and keybindings
- **script/** — the setup script and its config file dependencies. Config files use placeholders (e.g. `__HOME__`, `__PROJECTS_DIR__`) that get substituted at runtime

### Current scripts

```
vscode/
├── create.md
├── update.md
└── script/
    ├── vscode-setup.sh
    ├── settings.json
    └── keybindings.json

terminal/
├── create.md
├── update.md
└── script/
    ├── terminal-setup.sh
    └── Pro.terminal

claude-code-session-sync/          # Standalone utility, no update.md
├── create.md
├── initial-prompt.md
└── script/
    └── claude-code-session-sync.php   # Run with: php claude-code-session-sync/script/claude-code-session-sync.php
```

## Notes

