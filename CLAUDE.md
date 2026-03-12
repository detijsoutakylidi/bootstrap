# setup - shared scope

Project for creating and updating setup scripts

## Notes for collaborators

- This file is committed and shared.
- Put your PERSONAL instructions for Claude in @CLAUDE-personal-project..md file.

## Structure

Project root is the repo root. Scripts live under `bootstrap/`.

```
bootstrap/                         # Subdirectory (not the project root)
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
        ├── claude/
        │   ├── CLAUDE-djtl.md         # Company-enforced Claude Code rules (deployed to ~/.claude/)
        │   ├── new-project.sh         # macOS project creation script (copied from project projects)
        │   ├── new-project.ps1        # Windows project creation script
        │   ├── project-en.md          # CLAUDE.md template for new projects
        │   └── personal-en.md         # CLAUDE-personal-project..md template
        └── vscode/
            ├── settings.json          # Shared (placeholders substituted at runtime)
            ├── keybindings.json       # macOS (cmd-based)
            └── keybindings-win.json   # Windows (ctrl-based)
```

### Run

**macOS:** `bash bootstrap/script/bootstrap.sh [--install | --configure] [--base] [--vscode] [--vscode-assoc] [--claude] [--terminal] [--extended]`
**Windows:** `.\bootstrap\script\bootstrap.ps1 [--install | --configure] [--base] [--vscode] [--vscode-assoc] [--claude] [--terminal] [--extended]`

Both scripts auto-detect admin status, are idempotent, and support cloud install (see README).

- **create.md** — documents how the scripts were built, use as a template when adding new tools
- **update.md** — instructions for Claude to follow when syncing the scripts with the current machine's config
- **config/** — config files with placeholders (`__HOME__`, `__PROJECTS_DIR__`) substituted at runtime

## CLAUDE.md Architecture

Each scope (global and per-project) uses multiple CLAUDE files auto-loaded by Claude Code:

**Global (`~/.claude/`):** `CLAUDE.md` (personal, includes `@CLAUDE-djtl.md`) + `CLAUDE-djtl.md` (company, always overwritten by bootstrap). The `@` inclusion is required — bootstrap auto-adds it if missing.

**Per-project:** `CLAUDE.md` (committed) + `CLAUDE-personal-project..md` + `CLAUDE-djtl-global..md` → symlink to global + `CLAUDE-personal-global..md` → symlink to global. All `..` files are gitignored via `*..*` in gitignore_global.

Future: track personal global CLAUDE.md in a separate config project and symlink to `~/.claude/`.

## Notes

- **This repo is public.** Never commit secrets, tokens, API keys, passwords, or machine-specific paths. Config files must use placeholders (`__HOME__`, etc.) — verify before every commit.
- `config/claude/new-project.sh` and templates are copies from project `projects`. On update, re-copy from the source. Bootstrap deploys to `~/.claude/scripts/` and symlinks into the projects directory.
