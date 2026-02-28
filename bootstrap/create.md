# Bootstrap — Creation Playbook

Unified macOS bootstrap script combining devbase, terminal, vscode, and claude setups into a single `bootstrap.sh` with install/configure separation for non-admin user support.

## What was gathered

Combined from four individual setup scripts:
- **devbase**: Xcode CLT, Rosetta 2, Homebrew, Git, jq, ripgrep, gh, global gitignore
- **terminal**: Terminal.app Pro profile, shell prompt
- **vscode**: VS Code app, extensions, settings, keybindings, file associations (duti)
- **claude**: Claude Code, Claude Desktop, CodexBar, Chrome extension

## Decisions

- **Cloud-first**: Default install via `curl | bash` from public GitHub repo. Config files downloaded on demand from raw GitHub URLs.
- **Local fallback**: When run from a repo checkout, uses local config files instead of downloading.
- **Temp storage**: Downloaded config files go to `mktemp -d`, cleaned up via trap on exit.
- **Modes**: `--install` (system-level, needs admin), `--configure` (user-local, no admin), bare run auto-detects via `dseditgroup`
- **Section filters**: `--base`, `--vscode`, `--claude`, `--terminal` — combinable with each other and with `--install`/`--configure`. No section flags = all sections.
- **Non-admin support**: Standard macOS users run `--configure` only. An admin runs `--install` first (or the same user from their admin account).
- **Config files**: Copies maintained independently in `bootstrap/script/config/` — not symlinks, not references to original script folders
- **Original scripts preserved**: Individual `devbase/`, `terminal/`, `vscode/`, `claude/` scripts remain as archival reference
- **macOS only**: No Windows equivalent yet
- **Idempotent**: Every install checks if already present and skips. Every config step compares before overwriting.
- **Execution order**: Install: devbase → vscode → claude. Configure: devbase → terminal → vscode → claude.

## Structure

```
bootstrap/
├── create.md              # This file
├── update.md              # Playbook for syncing with live config
└── script/
    ├── bootstrap.sh       # Unified setup script
    └── config/
        ├── git/
        │   └── gitignore_global
        ├── terminal/
        │   └── Pro.terminal
        └── vscode/
            ├── settings.json          # Shared, uses __HOME__ / __PROJECTS_DIR__ placeholders
            ├── keybindings.json       # macOS (cmd-based)
            └── keybindings-win.json   # Windows (for future use)
```

## General template for adding new tools

1. Add `install_<tool>()` function in the install phase section — skip if already installed
2. Add `configure_<tool>()` function in the configure phase section — skip if already configured
3. Add config files (if any) under `bootstrap/script/config/<name>/` (name matches the config's domain, e.g. `git`, `vscode`, `terminal`)
4. Add a `do_<tool>()` section guard and wire it into the main execution block
5. Add a `--<tool>` flag to the argument parser
6. Update this create.md and update.md
