# Inconsistencies and Improvement Opportunities

Found during full project review on 2026-04-12.

## Build Stamp Not Updated

`BOOTSTRAP_BUILD="260312-2246"` in bootstrap.sh hasn't been updated since March 12. Every push should update this timestamp. Easy to forget — could be automated with a pre-commit hook or a reminder in the commit workflow.

**PS1 has the same issue** — its build stamp is also stale.

## PS1 Significantly Behind

The Windows script is missing:
- Intelligent merge functions (merge_lines_config, merge_json_config)
- Session retention check (cleanupPeriodDays)
- Herd section (N/A for Windows, but the flag parsing should still handle `--herd` gracefully)
- Git version detection fix (`git -C` vs `cd` for paths with spaces)

This is documented in `create.md` but there's no tracking issue.

## CodexBar Config Merge Type Mismatch

CodexBar `config.json` has a top-level `{"providers": [...]}` structure. The script merges it as `array:id`, which works because it passes the whole content. But if the file ever gains top-level keys beyond `providers`, the array merge would fail. Should probably be `object` merge with special handling for the `providers` array — or just document that it only works for the current structure.

## CLAUDE-djtl.md Output Style Section Inconsistency

The repo's `config/claude/CLAUDE-djtl.md` has a simplified Output Style section (2 bullet points), while `~/.claude/CLAUDE-djtl.md` (the global file loaded by Claude Code) has the same. But the user's personal `~/.claude/CLAUDE.md` has a more detailed version in `CLAUDE-djtl.md` (referenced via `@`). Since bootstrap always overwrites, user edits to the company rules file get lost. This is by design but worth noting.

## update.md References resolve-resource Skill

The update playbook (`update.md`) documents a manual comparison workflow, but doesn't mention the `resolve-resource` skill for cross-project lookups. The step "Diff new-project.sh from project projects" could reference the skill.

## README-en.md Still References Old Flag Set

The English README lists `--base`, `--vscode`, `--claude`, `--terminal` but is missing `--vscode-assoc` and `--herd`. Should be synced.

## Terminal Profile Change Detection Uses Python

`configure_terminal()` uses an inline Python script to compare plist profiles. This is the only place outside the merge system that uses Python. Works fine, but it's a hidden dependency — if Python 3 is missing, the terminal section would fail. Could add a check, but Python 3 is always present on macOS (via Xcode CLT).

## new-project.sh Has `open -a "Visual Studio Code" .`

The new-project.sh template (copied from projects repo) opens VS Code after creating a project. This assumes VS Code is installed, which is true for bootstrap users but could fail for others. Minor — it's a DJTL-internal tool.

## No `--help` Flag

The script prints usage on unknown flags but doesn't support `--help` or `-h` explicitly. Would be a nice addition.
