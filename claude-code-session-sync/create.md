# Claude Code Session Sync — Creation Playbook

How this script was created. Unlike other setup scripts, this is a standalone utility — no update.md needed.

## Problem

Claude Code's `sessions-index.json` goes stale — `.jsonl` session files exist on disk but aren't listed in the index, making them invisible to `/resume` in both CLI and VS Code. Both environments read the same index file at `~/.claude/projects/<project-id>/sessions-index.json`.

Related GitHub issues: #25032, #22723, #12819, #13872.

## Process

### 1. Reverse-engineer storage format

Explored the actual files on the machine to understand:

- **Session storage:** `~/.claude/projects/<project-id>/<uuid>.jsonl` — one file per session, each line a JSON event (user message, assistant message, progress, file-history-snapshot, queue-operation)
- **Session index:** `~/.claude/projects/<project-id>/sessions-index.json` — version 1 format with `entries` array and `originalPath`
- **Project ID encoding:** path with `/` replaced by `-`, prefixed with `-` (e.g., `/Users/martin/Local Sites/setup` → `-Users-martin-Local-Sites-setup`)
- **VS Code uses the same index** — no separate storage. The VS Code extension reads `sessions-index.json` just like the CLI does.

### 2. Design the sync script

Single PHP CLI script that:
- Scans all project directories under `~/.claude/projects/`
- Compares `.jsonl` files on disk against `sessions-index.json` entries
- Extracts metadata from orphaned `.jsonl` files by parsing their contents
- Dry-run by default, `--write` to actually update indexes

### 3. Key schema details

**sessions-index.json entry fields:**
- `sessionId`, `fullPath`, `fileMtime` (ms epoch)
- `firstPrompt` (first user message or "No prompt")
- `messageCount` (user + assistant messages)
- `created`, `modified` (ISO 8601)
- `gitBranch`, `projectPath`, `isSidechain`
- `summary` (optional)

**JSONL event types:** `user`, `assistant`, `progress`, `file-history-snapshot`, `queue-operation`
