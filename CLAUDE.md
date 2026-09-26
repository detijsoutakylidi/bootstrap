# setup - shared scope

Project for creating and updating setup scripts

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

**`--herd` is stale as of 2026-09-26 — do not run it on air, and rewrite it before running it anywhere.** Laravel Herd was uninstalled from air that day (it relaunched at login despite its own Launch-at-Login toggle being off, via a root `LaunchDaemon` and a Background Task Manager entry the toggle does not control). Two things in `install_herd()` no longer match reality: it installs Herd at all, and it configures the `.private` TLD by writing into `~/Library/Application Support/Herd/config/dnsmasq/dnsmasq.conf` and restarting Herd.app. `.private` has since moved off Herd entirely — it is served by Homebrew dnsmasq (`/opt/homebrew/sbin/dnsmasq`) reading `~/.djtl/private/dnsmasq/dnsmasq.conf`, with `/etc/resolver/private` pointing at `127.0.0.127` rather than Herd's `127.0.0.1`. So the section would reinstall an unwanted app and write config into a path nothing reads. PHP itself comes from Homebrew (`/opt/homebrew/opt/php@8.5`), selected per project by the `private` shim at `~/.djtl/private/bin/php`; `private`'s own daemons name the versioned Homebrew path directly. `config/boost.json` also still lists Herd MCP as a DJTL default.

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

**Global (`~/.claude/`):** Personal + company prefs are auto-loaded from `~/.claude/rules/` (every `*.md` there loads globally, no `@` import). Canonical sources live in the **`global`** project. On any bootstrapped machine, bootstrap deploys a plain copy of the company rules to `~/.claude/rules/djtl.md` (skips if it's a symlink) and seeds a personal `~/.claude/CLAUDE.md` stub. The old `@CLAUDE-djtl.md` import is retired.

> ### ⚠️ STALE vs `global` — bootstrap is out of date (noted 2026-08-11)
>
> **Bootstrap is not in use right now, and this is deliberately not being fixed yet.** Read this
> before running or editing bootstrap; do not assume the paragraph above is current.
>
> The `global` project restructured on 2026-08-10 and no longer produces the files bootstrap expects:
>
> | bootstrap expects | `global` actually has now |
> |---|---|
> | single `global/company/CLAUDE.md` | `global/rules/djtl/*.md` — **8 topic files** |
> | single `global/personal/CLAUDE.md` | `global/rules/personal/*.md` — **7 topic files** |
> | deploy target `~/.claude/rules/djtl.md` | on Martin's machine: `~/.claude/rules/djtl/` — a **directory** symlink |
> | seeds a `~/.claude/CLAUDE.md` stub | deleted on Martin's machine 2026-08-11 (a user-scope breadcrumb is resident context in every session) |
>
> **What the fix will need:** the snapshot step must concatenate `rules/djtl/*.md` into the bundled
> `config/claude/CLAUDE-djtl.md`, or bootstrap must learn to deploy the folder split. Its skip-if-symlink
> check must also handle the target being a *directory* symlink, not just a file symlink.
>
> **Until then a freshly bootstrapped machine gets company rules frozen at the pre-split snapshot.**
> Tracked in `global/CLAUDE.md` (Related / open) and `global/.claude/docs/setup.md`.

**Per-project:** `CLAUDE.md` (committed) + `CLAUDE-personal-project..md` (gitignored via `*..*`). The per-project `CLAUDE-djtl-global..md` / `CLAUDE-personal-global..md` symlink stubs are no longer created (global prefs now come from `~/.claude/rules/`).

The `global` config project is the realization of the previously-planned "track personal/company global CLAUDE.md in a separate config project and symlink to `~/.claude/`."

## Notes

- **This repo is public.** Never commit secrets, tokens, API keys, passwords, or machine-specific paths. Config files must use placeholders (`__HOME__`, etc.) — verify before every commit.
- `config/claude/new-project.sh` and templates are copies from project `projects`. On update, re-copy from the source. Bootstrap deploys to `~/.claude/scripts/` and symlinks into the projects directory.
- **Changelog:** Update `CHANGELOG.md` with every commit. Group entries by date, one line per change.
- **Build stamp:** Update `BOOTSTRAP_BUILD` in `bootstrap.sh` (line ~1257) before each push. Format: `YYMMDD-HHMM` (e.g. `260412-1758`).
