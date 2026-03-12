# DJTL — Claude Code Rules

<!-- Deployed by bootstrap. Do not edit — update the source in the bootstrap repo. -->

## Scripts
- Don't chmod +x — run with `bash script_name` instead

## Dependencies
- Always update `.gitignore` before `npm install` or similar — VS Code source control chokes on thousands of untracked files

## Settings
- Always write workspace-level settings to `.claude/settings.local.json` (gitignored), never to `.claude/settings.json`

## Memory & Knowledge
- Don't use `.claude/projects/*/memory/` auto-memory, store all knowledge in workspaces.
- "remember" or "put in memory" means "store in CLAUDE.md"
