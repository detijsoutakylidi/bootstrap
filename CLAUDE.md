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
    ├── test-merge.sh              # Tests for merge functions (bash test-merge.sh)
    ├── test-bootstrap.sh          # Tests for bootstrap logic (bash test-bootstrap.sh)
    └── config/
        ├── git/
        │   └── gitignore_global
        ├── terminal/
        │   ├── Pro.terminal                    # macOS Terminal.app profile
        │   └── windows-terminal-profile.json   # Windows Terminal color scheme + defaults
        ├── claude/
        │   ├── CLAUDE-djtl.md         # Company-enforced rules snapshot from global/company (deployed as copy to ~/.claude/rules/djtl.md)
        │   ├── new-project.sh         # macOS project creation script (copied from project projects)
        │   ├── new-project.ps1        # Windows project creation script
        │   └── project-en.md          # CLAUDE.md template for new projects
        ├── codexbar/
        │   ├── config.json            # CodexBar provider config
        │   └── defaults.plist         # CodexBar app preferences
        └── vscode/
            ├── settings.json          # Shared (placeholders substituted at runtime)
            ├── keybindings.json       # macOS (cmd-based)
            └── keybindings-win.json   # Windows (ctrl-based)
```

### Run

**macOS:** `bash bootstrap/script/bootstrap.sh [--install | --configure] [--base] [--vscode] [--vscode-assoc] [--claude] [--terminal] [--herd] [--extended]`
**Windows:** `.\bootstrap\script\bootstrap.ps1 [--install | --configure] [--base] [--vscode] [--vscode-assoc] [--claude] [--terminal] [--extended]`

`--herd` is opt-in (not in default set). Also offered interactively via `--extended`.

Both scripts auto-detect admin status, are idempotent, and support cloud install (see README).

- **create.md** — documents how the scripts were built, use as a template when adding new tools
- **update.md** — instructions for Claude to follow when syncing the scripts with the current machine's config
- **config/** — config files with placeholders (`__HOME__`, `__PROJECTS_DIR__`) substituted at runtime

### Project-scope configs

```
bootstrap/project/                 # Project-scope config templates (copied into projects, not deployed globally)
└── laravel-boost/
    └── boost.json                 # Laravel Boost pre-config (DJTL defaults: Claude Code, Herd MCP, Livewire/Tailwind/Flux skills)
```

Reference doc for Laravel Boost setup lives in the `tools` project: `docs/laravel-boost.md`.

## CLAUDE.md Architecture

Each scope (global and per-project) uses multiple CLAUDE files auto-loaded by Claude Code:

**Global (`~/.claude/`):** Personal + company prefs are auto-loaded from `~/.claude/rules/` (every `*.md` there loads globally, no `@` import). Canonical sources live in the **`global`** project: `global/personal/CLAUDE.md` and `global/company/CLAUDE.md`. On Martin's machine `~/.claude/rules/personal.md` and `~/.claude/rules/djtl.md` are symlinks to those; `~/.claude/CLAUDE.md` + `CLAUDE-djtl.md` remain as breadcrumbs. On any bootstrapped machine, bootstrap deploys a plain copy of the company rules to `~/.claude/rules/djtl.md` (skips if it's a symlink) and seeds a personal `~/.claude/CLAUDE.md` stub. The old `@CLAUDE-djtl.md` import is retired.

**Per-project:** `CLAUDE.md` (committed) + `CLAUDE-personal-project..md` (gitignored via `*..*`). The per-project `CLAUDE-djtl-global..md` / `CLAUDE-personal-global..md` symlink stubs are no longer created (global prefs now come from `~/.claude/rules/`).

The `global` config project is the realization of the previously-planned "track personal/company global CLAUDE.md in a separate config project and symlink to `~/.claude/`."

## Notes

- **This repo is public.** Never commit secrets, tokens, API keys, passwords, or machine-specific paths. Config files must use placeholders (`__HOME__`, etc.) — verify before every commit.
- `config/claude/new-project.sh` and templates are copies from project `projects`. On update, re-copy from the source. Bootstrap deploys to `~/.claude/scripts/` and symlinks into the projects directory.
- **Changelog:** Update `CHANGELOG.md` with every commit. Group entries by date, one line per change.
- **Build stamp:** Update `BOOTSTRAP_BUILD` in `bootstrap.sh` (line ~1257) before each push. Format: `YYMMDD-HHMM` (e.g. `260412-1758`).
