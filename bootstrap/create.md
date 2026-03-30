# Bootstrap — Creation Playbook

Unified bootstrap scripts (`bootstrap.sh` for macOS, `bootstrap.ps1` for Windows) combining devbase, terminal, vscode, and claude setups with install/configure separation for non-admin user support.

## What was gathered

Combined from four individual setup scripts (now deleted — consolidated here):
- **devbase**: Xcode CLT, Rosetta 2, Homebrew (macOS) / winget (Windows), Git, jq, ripgrep, gh, global gitignore
- **terminal**: Terminal.app Pro profile (macOS) / Windows Terminal profile + PowerShell prompt (Windows)
- **vscode**: VS Code app, extensions, settings, keybindings, file associations (duti on macOS, assoc/ftype on Windows)
- **claude**: Claude Code, Claude Desktop, CodexBar (macOS only), Chrome extension, CLAUDE-djtl.md company rules, new-project script

## Decisions

- **Cloud-first**: Default install via `bash <(curl ...)` (macOS) or `& ([scriptblock]::Create((irm <url>)))` (Windows). Config files downloaded on demand from raw GitHub URLs.
- **Local fallback**: When run from a repo checkout, uses local config files instead of downloading.
- **Temp storage**: Downloaded config files go to temp dir, cleaned up on exit (trap on macOS, try/finally on Windows).
- **Modes**: `--install` (system-level, needs admin), `--configure` (user-local, no admin), bare run auto-detects admin status (`dseditgroup` on macOS, `WindowsPrincipal.IsInRole` on Windows).
- **Section filters**: `--base`, `--vscode`, `--claude`, `--terminal` — combinable with each other and with `--install`/`--configure`. No section flags = all sections.
- **Non-admin support**: Standard users run `--configure` only. An admin runs `--install` first.
- **Config files**: All maintained in `bootstrap/script/config/` — not symlinks.
- **Shared configs**: `settings.json` and `gitignore_global` are shared across platforms. `keybindings.json` (macOS) and `keybindings-win.json` (Windows) are platform-specific. Terminal profiles are platform-specific.
- **Windows settings patches**: At runtime, the shared `settings.json` gets macOS-only settings removed (`window.nativeFullScreen`) and `ctrlCmd` replaced with `alt` for multiCursorModifier.
- **File associations in install phase (Windows)**: `assoc`/`ftype` require admin, so file associations are in Install-Vscode (not Configure-Vscode).
- **Idempotent**: Every install checks if already present and skips. Every config step compares before overwriting. Config updates offer Skip / Overwrite / Merge (intelligent key-based merge for JSON via embedded Python, line-based merge for gitignore).
- **PS1 out of sync**: `bootstrap.ps1` still uses the old Skip/Overwrite logic for config files. The merge functions (`merge_lines_config`, `merge_json_config`) were only added to `bootstrap.sh`. Port when Windows testing resumes.
- **CLAUDE-djtl.md**: Always overwritten — company-enforced rules, no skip/ask. Bootstrap ensures global `~/.claude/CLAUDE.md` exists and includes `@CLAUDE-djtl.md` (auto-adds if missing).
- **new-project scripts**: Deployed to `~/.claude/scripts/` with templates, symlinked into projects directory for easy access. On Windows, symlink creation requires Developer Mode or admin — falls back to copy with warning.
- **Execution order**: Install: base → vscode → claude. Configure: base → terminal → vscode → claude.

## Structure

```
bootstrap/
├── create.md              # This file
├── update.md              # Playbook for syncing with live config
└── script/
    ├── bootstrap.sh       # macOS unified setup script
    ├── bootstrap.ps1      # Windows unified setup script
    └── config/
        ├── git/
        │   └── gitignore_global
        ├── terminal/
        │   ├── Pro.terminal                    # macOS Terminal.app profile
        │   └── windows-terminal-profile.json   # Windows Terminal color scheme + defaults
        ├── claude/
        │   ├── CLAUDE-djtl.md         # Company rules (deployed to ~/.claude/, always overwritten)
        │   ├── new-project.sh         # macOS project creation (copied from project projects)
        │   ├── new-project.ps1        # Windows project creation (symlink fallback to copy)
        │   ├── project-en.md          # CLAUDE.md template for new projects
        │   └── personal-en.md         # CLAUDE-personal-project..md template
        ├── codexbar/
        │   ├── config.json            # Provider config (~/.codexbar/config.json)
        │   └── defaults.plist         # App preferences (defaults domain, merged on import)
        └── vscode/
            ├── settings.json          # Shared, uses __HOME__ / __PROJECTS_DIR__ placeholders
            ├── keybindings.json       # macOS (cmd-based)
            └── keybindings-win.json   # Windows (ctrl-based)
```

## General template for adding new tools

1. Add install function in the install phase section — skip if already installed (both .sh and .ps1)
2. Add configure function in the configure phase section — skip if already configured (both .sh and .ps1)
3. Add config files (if any) under `bootstrap/script/config/<name>/`
4. Add a section guard and wire it into the main execution block
5. Add a `--<tool>` flag to the argument parser
6. Update this create.md and update.md
