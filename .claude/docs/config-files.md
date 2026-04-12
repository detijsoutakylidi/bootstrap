# Config Files Reference

All config files live in `bootstrap/script/config/` and are fetched at runtime via `fetch_config()`.

## Git

| File | Target | Merge | Deployed by |
|------|--------|-------|-------------|
| `git/gitignore_global` | `~/.gitignore_global` | lines | `configure_devbase()` |

## VS Code

| File | Target | Merge | Deployed by |
|------|--------|-------|-------------|
| `vscode/settings.json` | `~/Library/.../Code/User/settings.json` | JSON object | `configure_vscode()` |
| `vscode/keybindings.json` | `~/Library/.../Code/User/keybindings.json` | JSON array:key,command | `configure_vscode()` |
| `vscode/keybindings-win.json` | `%APPDATA%\Code\User\keybindings.json` | skip/overwrite (PS1) | Windows only |

**Placeholders** in settings.json: `__HOME__` → `$HOME`, `__PROJECTS_DIR__` → user's projects dir. Substituted via `sed` at runtime. Never commit resolved paths.

## Terminal

| File | Target | Merge | Deployed by |
|------|--------|-------|-------------|
| `terminal/Pro.terminal` | Terminal.app defaults | skip/overwrite (plist) | `configure_terminal()` |
| `terminal/windows-terminal-profile.json` | Windows Terminal settings | JSON merge (PS1) | Windows only |

## Claude Code

| File | Target | Merge | Deployed by |
|------|--------|-------|-------------|
| `claude/CLAUDE-djtl.md` | `~/.claude/CLAUDE-djtl.md` | **always overwrite** | `configure_claude()` |
| `claude/new-project.sh` | `~/.claude/scripts/new-project.sh` | always overwrite | `configure_claude()` |
| `claude/project-en.md` | `~/.claude/scripts/project-en.md` | always overwrite | `configure_claude()` |
| `claude/personal-en.md` | `~/.claude/scripts/personal-en.md` | always overwrite | `configure_claude()` |

**CLAUDE-djtl.md** is company-enforced — no merge, no ask. `new-project.sh` and templates are copies from the `projects` repo — re-copy from source on update.

## CodexBar

| File | Target | Merge | Deployed by |
|------|--------|-------|-------------|
| `codexbar/config.json` | `~/.codexbar/config.json` | JSON array:id | `configure_claude()` |
| `codexbar/defaults.plist` | macOS defaults database | `defaults import` (merge) | `configure_claude()` |

## Herd

No config files in the repo. `install_herd()` modifies two system files directly:

- **Herd's dnsmasq.conf** (`~/Library/Application Support/Herd/config/dnsmasq/dnsmasq.conf`) — appends `address=/.private/127.0.0.1` for wildcard `*.private` resolution
- **macOS resolver** (`/etc/resolver/private`) — creates with `nameserver 127.0.0.1` so macOS routes `.private` queries to Herd's dnsmasq

Both are idempotent (check before writing). Each project registers its own nginx proxy config with Herd independently.
