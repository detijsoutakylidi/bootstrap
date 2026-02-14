# VS Code Setup — Creation Playbook

How this setup script was created. Use as a template when creating new setup scripts.

## Process

### 1. Gather current state

Read the tool's existing config files from the machine. For VS Code this was:
- `~/Library/Application Support/Code/User/settings.json`
- `~/Library/Application Support/Code/User/keybindings.json`
- `code --list-extensions` for installed extensions
- Snippets folder

### 2. Ask scoping questions

Before writing anything, ask the user about:
- **Install method** — how should the tool be installed (brew, direct download, etc.)
- **Idempotency** — should the script be safe to re-run?
- **Machine-specific values** — identify hardcoded paths or machine-specific config. Decide: hardcode, use placeholders with runtime substitution, or prompt at runtime
- **Config scope** — include everything as-is, or let user cherry-pick?

### 3. Interactive selection

Present lists of things to include (extensions, plugins, config sections) and let the user choose:
- **Essential** — always installed, no prompt
- **Optional** — script asks y/n at runtime
- **Excluded** — not included in the script

Group similar items together (e.g. PHP extensions next to each other) for easier scanning.

### 4. Clean up config before storing

Before copying config into the script dependencies:
- Remove references to uninstalled extensions/plugins (orphaned settings, keybindings)
- Reorganize into logical groups with comment headers: `// group name — description`
- Add explanatory comments where the purpose isn't obvious (especially keybindings)
- Back up files before reorganizing (`.bak`)

### 5. Create the script structure

```
<tool>/
├── create.md              # This file — how the script was created
├── update.md              # Claude playbook for syncing script with live config
└── script/
    ├── <tool>-setup.sh    # Main setup script
    └── <config-files>     # Config files with placeholders where needed
```

### 6. Write the setup script

The script should:
- Use `set -euo pipefail`
- Have colored output helpers (`info`, `ok`, `ask`)
- Install prerequisites (e.g. Homebrew)
- Install the tool itself (skip if already installed)
- Prompt for runtime values (e.g. projects directory) with sensible defaults
- Create directories that need to exist
- Install essential items without prompting
- Ask y/n for optional items
- Copy config files, substituting placeholders with runtime values via `sed`
- Be idempotent — check before each step, skip if already done

### 7. Create the update playbook

Write `update.md` with instructions for Claude to follow when syncing the script with current config. Should include:
- **Step 0 — Revision** — offer to clean up and reorganize live config before syncing
- **Extension/plugin comparison** — diff installed vs script lists
- **Config comparison** — diff live vs stored files (accounting for placeholders)
- **Finalize** — verify placeholders intact, ask to commit

### 8. Commit

Single commit with all files: script, config dependencies, create.md, update.md, and CLAUDE.md updates.
