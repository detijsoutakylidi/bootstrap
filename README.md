# bootstrap

Setup scripts for bootstrapping a new machine with Claude in VS Code and related tools.

## macOS

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh)
```

Auto-detects admin access. On admin accounts, installs system tools + configures user environment. On standard accounts, configures only (warns about missing tools).

### Section parameters

Run specific parts instead of the full bootstrap:

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --vscode                   # VS Code only
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --configure --terminal     # configure terminal only
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --install --base --vscode  # install base + vscode only
```

Available sections: `--base`, `--vscode`, `--claude`, `--terminal`

Combinable with `--install` / `--configure` and with each other. No section flags = all sections.

### Non-admin users

If you use a separate standard (non-admin) account for daily work:

1. From your standard account, switch to the admin user and install system tools:

```bash
su - adminusername
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --install
exit
```

2. From your standard account — configure your environment:

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --configure
```

Each script is idempotent — safe to re-run on an already-configured machine.

---

## What each section installs / configures

### `--base`

**Install** (requires admin):
- Xcode Command Line Tools
- Rosetta 2 (Apple Silicon only)
- Homebrew
- Git, jq, ripgrep, GitHub CLI (via brew)

**Configure** (user-level):
- Global gitignore (`~/.gitignore_global`) with skip/overwrite/merge options

### `--vscode`

**Install** (requires admin):
- Visual Studio Code (via brew cask)
- duti (file association tool)

**Configure** (user-level):
- `code` CLI in PATH
- Projects directory (default: `~/Projects`)
- Essential extensions: Claude Code, Catppuccin Theme, Project Manager, Duplicate Action, SFTP, Peacock, Markdown Editor
- Optional extensions (prompted): Intelephense (PHP), Toggle Quotes, Terraform
- `settings.json` and `keybindings.json` with skip/overwrite options
- File associations (.json, .xml, .js, .vtt, .md, .jsonl, .srt, .pub, .tf, .tfstate → VS Code)

### `--claude`

**Install** (requires admin):
- Claude Code (native installer)
- Claude Desktop (via brew cask)
- CodexBar (via brew cask, steipete/tap)

**Configure** (user-level):
- Opens Chrome Web Store for Claude browser extension
- Displays manual post-install steps (login, auth, connectors)

### `--terminal`

**Configure only** (no install phase):
- Terminal.app Pro profile import with skip/overwrite options
- Shell prompt (`PROMPT='%1~ % '` in `~/.zshrc`)
