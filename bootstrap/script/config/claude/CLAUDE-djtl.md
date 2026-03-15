# DJTL — Claude Code Rules

<!-- Deployed by bootstrap. Do not edit — update the source in the bootstrap repo. -->

## Output Style
- Do small tasks directly via tools; don't hand me commands to paste. For bigger things, offer options and ask.
- Always provide clickable URLs/links — don't just describe where to go.
- When giving text to copy, use code blocks for one-click copying.

## Scripts
- Don't chmod +x — run with `bash script_name` instead

## Dependencies
- Always update `.gitignore` before `npm install` or similar — VS Code source control chokes on thousands of untracked files

## Settings
- Always write workspace-level settings to `.claude/settings.local.json` (gitignored), never to `.claude/settings.json`

## Memory & Knowledge
- Don't use `.claude/projects/*/memory/` auto-memory, store all knowledge in workspaces.
- "remember" or "put in memory" means "store in CLAUDE.md"

## Cross-Project Changes
- When changes span multiple projects, ask the user before finishing: (1) just make the changes, (2) commit, or (3) commit and push — across all affected projects.

## Kyblik
- `kyblik/` is a general-purpose bucket folder (globally gitignored) for files that don't have a clear home yet. Can live anywhere in the project tree — defaults to project root unless there's a reason to go deeper.
- When placing files there, always provide a clickable link: `[filename](kyblik/filename)` so the user can inspect immediately.
- `kyblik/tmp/` — session-scoped temporary files. Visible to the user, useful during the current session, but no lasting value. Working tool outputs, intermediate results the user wants to inspect. Can be cleaned up between sessions.
- Regular `kyblik/` files (outside tmp) — files that have value but need further sorting or placement. Claude doesn't know where they belong yet, so they wait here for the user to triage.
- If unsure whether to use an existing kyblik or create one in a subfolder, ask.
