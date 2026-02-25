# bootstrap

Setup scripts for bootstrapping a new dev machine (macOS + Windows).

## Usage

### macOS

```bash
# 1. Base system prerequisites (Xcode CLT, Homebrew, CLI tools)
bash devbase/script/devbase-setup.sh

# 2. Then any combination of:
bash claude/script/claude-setup.sh
bash vscode/script/vscode-setup.sh
bash terminal/script/terminal-setup.sh
```

### Windows

Run in PowerShell (as Administrator for devbase):

```powershell
# 1. Base system prerequisites (winget, Git, CLI tools)
.\devbase-setup-win.ps1

# 2. Then any combination of:
.\claude-setup-win.ps1
.\vscode-setup-win.ps1
.\terminal-setup-win.ps1
```

If script execution is blocked, run first: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

Each script is idempotent — safe to re-run on an already-configured machine.
