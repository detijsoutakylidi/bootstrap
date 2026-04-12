# Platform Differences

## macOS (bootstrap.sh) vs Windows (bootstrap.ps1)

### Package Management

| | macOS | Windows |
|---|---|---|
| System | Homebrew | winget |
| Apps | `brew install --cask` | `winget install` |
| CLI tools | `brew install` | `winget install` |

### File Associations

| | macOS | Windows |
|---|---|---|
| Tool | `duti` (via brew) | `assoc` / `ftype` (built-in) |
| Phase | Configure (user-level) | Install (admin required) |
| Detection | `duti -d` (UTI) / `duti -x` (extension) | `assoc .ext` |

### VS Code Keybindings

macOS uses `cmd`-based, Windows uses `ctrl`-based. Separate files: `keybindings.json` (macOS) and `keybindings-win.json` (Windows).

### Terminal

| | macOS | Windows |
|---|---|---|
| App | Terminal.app | Windows Terminal |
| Profile format | Binary plist | JSON |
| Shell | zsh (`~/.zshrc`) | PowerShell (`$PROFILE`) |
| Prompt | `PROMPT='%1~ % '` | Custom `prompt` function |

### Paths

| | macOS | Windows |
|---|---|---|
| VS Code config | `~/Library/Application Support/Code/User/` | `%APPDATA%\Code\User\` |
| Claude home | `~/.claude/` | `%USERPROFILE%\.claude\` |
| Projects default | `~/Projects` | `~\Projects` |

## PS1 Sync Status

The Windows script is behind on:
- **Merge functions** — PS1 still uses Skip/Overwrite only (no merge_json_config / merge_lines_config)
- **Herd section** — macOS only (Herd is macOS-only)
- **Session retention** — not yet added to PS1
- **Git version detection** — PS1 still uses `git -C` (may fail with spaces in path)

Port these when Windows testing resumes.
