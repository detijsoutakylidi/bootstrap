# bootstrap

Setup scripts for bootstrapping a new machine with Claude in VS Code and related tools.

## macOS

```bash
bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh)
```

## Windows

```powershell
& ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1)))
```

---

Auto-detects admin access. On admin accounts, installs system tools + configures user environment. On standard accounts, configures only (warns about missing tools).

### Section parameters

Run specific parts instead of the full bootstrap:

```
--vscode                   # VS Code only (install + configure)
--configure --terminal     # configure terminal only
--install --base --vscode  # install base + vscode only
```

Available sections: `--base`, `--vscode`, `--claude`, `--terminal`

Combinable with `--install` / `--configure` and with each other. No section flags = all sections.

### Non-admin users

If you use a separate standard (non-admin) account for daily work:

**macOS:**

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

**Windows:**

1. Run PowerShell as Administrator and install system tools:

```powershell
& ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1))) --install
```

2. From a normal PowerShell — configure your environment:

```powershell
& ([scriptblock]::Create((irm https://djtl.cz/gh/bootstrap.ps1))) --configure
```

Each script is idempotent — safe to re-run on an already-configured machine.

---

## What each section installs / configures

### `--base`

**Install** (requires admin):
- macOS: Xcode Command Line Tools, Rosetta 2, Homebrew, Git, jq, ripgrep, GitHub CLI
- Windows: winget check, jq, ripgrep, Git, GitHub CLI (via winget)

**Configure** (user-level):
- Global gitignore (`~/.gitignore_global`) with skip/overwrite/merge options

### `--vscode`

**Install** (requires admin):
- Visual Studio Code (brew cask on macOS, winget on Windows)
- macOS: duti (file association tool)
- Windows: file associations via assoc/ftype (.json, .xml, .js, .md, .jsonl, .srt, .pub, .tf, .tfstate, .vtt)

**Configure** (user-level):
- macOS: `code` CLI in PATH
- Projects directory (default: `~/Projects`)
- Essential extensions: Claude Code, Catppuccin Theme, Project Manager, Duplicate Action, SFTP, Peacock, Markdown Editor
- Optional extensions (prompted): Intelephense (PHP), Toggle Quotes, Terraform
- `settings.json` and `keybindings.json` with skip/overwrite options
- macOS: file associations (.json, .xml, .js, .vtt, .md, .jsonl, .srt, .pub, .tf, .tfstate via duti)

### `--claude`

**Install** (requires admin):
- Claude Code (native installer)
- Claude Desktop (brew cask on macOS, winget on Windows)
- macOS only: CodexBar (brew cask, steipete/tap)

**Configure** (user-level):
- Opens Chrome Web Store for Claude browser extension
- Displays manual post-install steps (login, auth, connectors)

### `--terminal`

**Configure only** (no install phase):
- macOS: Terminal.app Pro profile import with skip/overwrite options, shell prompt in `~/.zshrc`
- Windows: Windows Terminal Pro color scheme + profile defaults, PowerShell prompt
