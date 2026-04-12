# Changelog

<!-- Update this file with every commit. Group entries by date. Keep entries concise — one line per change. -->

## 2026-04-12

- Added `--herd` section: installs Laravel Herd and configures `.private` TLD in `/etc/hosts`. Opt-in only, also offered via `--extended`.
- Added `.claude/docs/`: architecture, merge system, adding new tools, config files reference, platform differences, inconsistencies.

## 2026-03-31

- Intelligent config merge: Skip / Overwrite / Merge for VS Code settings, keybindings, CodexBar config, and gitignore. JSON merge uses embedded Python for key-based diffing with JSONC support. Line-based merge for gitignore. All bash 3.2 compatible.
- Session retention check: bootstrap now checks `cleanupPeriodDays` in `~/.claude/settings.json` and recommends setting it to 90000 days to prevent automatic session deletion.
- Synced all config files from live machine (VS Code settings/keybindings, CLAUDE-djtl, CodexBar).
- 15 automated tests for merge functions.
- Added CHANGELOG.md.
- Added `test-merge.sh` and `codexbar/` to CLAUDE.md structure.
- Czech README for non-technical users, English version moved to README-en.md.

## 2026-03-21

- Added PHP tooling (Intelephense CLI, php-lsp plugin) to `--extended` flag.
- Moved `boost.json` to `project/laravel-boost/`.

## 2026-03-15

- Added `kyblik/` bucket folder convention to global gitignore and CLAUDE-djtl.
- Added cross-project changes rule to CLAUDE-djtl.

## 2026-03-14

- Added `.env` to global gitignore.

## 2026-03-13

- Added Output Style section to CLAUDE-djtl company rules.

## 2026-03-12

- Fixed idempotency issues (#1-#6): Claude Code install detection, Projects folder prompt, file associations, Chrome extension, manual steps.
- Fixed Homebrew Claude Code detection (#7): `brew list --formula claude-code` instead of `brew list claude` which matched Claude Desktop cask. Uninstall targets formula, not cask.
- Fixed file associations returning `-1`: `head()` formatting function shadowed `/usr/bin/head`, breaking all `| head -1` pipes. Renamed to `section()`.
- Banner now shows build timestamp + git hash, with confirmation prompt before running.
- Added `--vscode-assoc` flag to run file associations section only.
- Fixed version detection for remote (curl) runs — hardcoded timestamp instead of git hash.
- Synced new-project scripts and templates from projects repo.
- Updated CLAUDE.md to shared scope format with architecture docs.

## 2026-03-11

- Added admin PowerShell elevation step to Windows non-admin instructions.

## 2026-03-09

- Added PDF Viewer as optional VS Code extension.
- Added CodexBar config deployment (config.json + preferences plist).
- Expanded global gitignore.

## 2026-03-08

- Added 1Password as optional VS Code extension.

## 2026-03-03

- Added Pencil as optional VS Code extension.

## 2026-03-02

- Added unified Windows `bootstrap.ps1`, mirroring macOS script structure.
- Removed partitioned script folders (devbase-setup, claude-setup, etc.) — fully consolidated.
- Added `--extended` flag to gate optional VS Code extensions.
- Removed `claude-code-session-sync` utility (superseded by upstream fixes).

## 2026-03-01

- Synced VS Code settings with live profile.

## 2026-02-28

- Added section parameters (`--base`, `--vscode`, `--claude`, `--terminal`) for selective runs.
- Added Markdown Editor to VS Code extensions.

## 2026-02-27

- Unified `bootstrap.sh` with cloud install (`bash <(curl ...)`) and admin/user phase separation.
- Added skip/overwrite prompts for config file overwrites.
- Added Git check and global gitignore bootstrap to devbase setup.
- Moved gitignore entries to global gitignore.

## 2026-02-25

- Added Windows variants of all four setup scripts.
- Disabled Option-as-Meta in Terminal profile (so Option types characters like `~`).
- Added Git for Windows to devbase setup.

## 2026-02-23

- Added Peacock to VS Code extensions, removed PHP Namespace Resolver.
- Added README.

## 2026-02-18

- Added devbase and claude setup scripts, harmonized all scripts.

## 2026-02-15

- Added Terminal.app setup script with Pro profile and prompt.
- Added Claude Code session index sync script and investigation notes (16KB buffer truncation bug).

## 2026-02-14

- Initial commit: VS Code setup script with config files and update playbook.
