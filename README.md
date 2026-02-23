# bootstrap

Setup scripts for bootstrapping a new macOS dev machine.

## Usage

```bash
# 1. Base system prerequisites (Xcode CLT, Homebrew, CLI tools)
bash devbase/script/devbase-setup.sh

# 2. Then any combination of:
bash claude/script/claude-setup.sh
bash vscode/script/vscode-setup.sh
bash terminal/script/terminal-setup.sh
```

Each script is idempotent — safe to re-run on an already-configured machine.
