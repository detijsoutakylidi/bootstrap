# Claude Code Session Index Sync Tool

## Problem

Claude Code stores session conversation data as `.jsonl` files in a shared location (`~/.claude/projects/<url-encoded-project-path>/`), but each environment maintains its own separate session index/registry:

- **Terminal CLI** reads from `~/.claude/projects/<project>/sessions-index.json`
- **VS Code extension** reads from VS Code workspace storage (`~/Library/Application Support/Code/User/workspaceStorage/<hash>/chatSessions/`)
- **Desktop app Code tab** has its own separate tracking (lower priority, skip for now)

This means sessions created in terminal are invisible in VS Code's `/resume` picker and vice versa. The underlying `.jsonl` data is shared, but discovery is siloed.

Confirmed bugs on GitHub:
- anthropics/claude-code#25032 — `sessions-index.json` not updated, stale/missing sessions
- anthropics/claude-code#22723 — Desktop app doesn't show CLI sessions
- anthropics/claude-code#12819 — VS Code `/resume` shows no conversations while terminal works
- anthropics/claude-code#13872 — VS Code chat history lost, session files not saved to workspace storage

## Goal

Build a CLI sync script (bash or PHP, your choice based on what fits better) that:

1. Reads the CLI session index (`sessions-index.json`) and discovers any `.jsonl` session files not listed in it
2. Reads the VS Code workspace storage session index and discovers sessions there
3. Produces a unified view — ensures both indexes know about all sessions from both environments
4. Can be run manually or via cron/launchd as a periodic sync

## Key considerations

- The `sessions-index.json` structure needs to be reverse-engineered from existing files on my machine. Start by examining actual files before writing any code.
- VS Code workspace storage uses a hash-based directory (`<hash>/`) per workspace. Map workspace to project path.
- The VS Code session storage format (`.json` files in `chatSessions/`) likely differs from CLI's `sessions-index.json`. Understand both schemas first.
- Don't corrupt either index — always back up before writing.
- macOS only (for now).
- Start with read-only discovery/diff mode before implementing write/sync.

## Approach

Phase 1: Explore and document both index formats on my machine.
Phase 2: Build read-only diff tool — show which sessions exist where.
Phase 3: Add write capability to sync missing entries into both indexes.

Start with Phase 1. Examine the actual files and report what you find.
