# Claude Code Session Discovery — Investigation Notes

## Context

Built a PHP sync tool to fix orphaned `.jsonl` sessions missing from `sessions-index.json`. During testing, discovered Terminal CLI `/resume` shows far fewer sessions than VS Code for the same project. Investigated the root cause by reverse-engineering the compiled CLI binary.

## Root cause: 16KB buffer truncation bug

**The Terminal CLI reads only the first 16,384 bytes of each `.jsonl` file to extract the session preview.** VS Code sessions include base64-encoded images (screenshots) in their first user message, making the message line ~61KB. The 16KB buffer truncates the JSON line mid-way, the parser fails silently, and the session is filtered out as having "no first prompt."

### The code path (from CLI binary v2.1.42)

1. `dpT(dir)` — scans directory for `.jsonl` files, validates UUID filenames, returns Map of `{path, mtime, ctime, size}`
2. `SNT(dir, limit, projectPath)` — calls `dpT`, creates "lite" session entries (no content parsed yet), sorts by mtime
3. `V1T(sessions, startIndex, count)` — paginates through sessions, calls `ky8` for each
4. `ky8(session, buffer)` — enriches lite entry by calling `by8`, then **filters**:
   - `if (!_.firstPrompt && !_.customTitle) return null` — **this is the filter**
   - `if (_.isSidechain || _.teamName) return null`
5. `by8(path, fileSize, buffer)` — reads first `AyR` (16,384) bytes, calls `yy8` to extract prompt
6. `yy8(chunk)` — scans lines in the chunk for the first non-meta user message, extracts text content

### Why it fails for VS Code sessions

VS Code user messages contain IDE context as a content array:
```json
{
  "type": "user",
  "message": {
    "content": [
      {"type": "text", "text": "<ide_opened_file>...</ide_opened_file>"},
      {"type": "image", ...},           // ← base64 screenshot, ~61KB
      {"type": "text", "text": "Can I have Claude icon on the vertical bar in VS Code?"}
    ]
  }
}
```

The preceding events (queue-operation + file-history-snapshot + progress) consume ~900 bytes. The remaining ~15,400 bytes of the 16KB window capture only part of the 61KB user message line. `JSON.parse()` fails on the truncated line → `firstPrompt` = `""` → session filtered out.

CLI sessions have small first user messages (472-496 bytes) that fit easily within the buffer.

### Session inventory (company project, 15 files)

| SID      | Origin   | First event          | Msgs | Size     | Prompt in 16KB? | Shown in Terminal? |
|----------|----------|----------------------|------|----------|------------------|--------------------|
| e0a8dc31 | CLI      | file-history-snapshot| 485  | 2.6MB    | Yes (472B)       | Yes                |
| 8cee9e37 | CLI      | file-history-snapshot| 495  | 5.8MB    | Yes (496B)       | Yes                |
| f02ad9fc | CLI      | file-history-snapshot|   4  | 6.3KB    | Yes (496B)       | Yes                |
| c0be2887 | VS Code  | queue-operation      |   4  | 310KB    | No (truncated)   | No                 |
| c42ff77e | VS Code  | queue-operation      | 234  | 1.6MB    | No (truncated)   | No                 |
| 79906f13 | VS Code  | queue-operation      |  18  | 329KB    | No (truncated)   | No                 |
| 51a51361 | VS Code  | queue-operation      |  10  | 373KB    | No (truncated)   | No                 |
| 3ba24b2b | CLI      | progress             |   0  | 2.5KB    | No (no user msg) | No                 |
| 4809388e | CLI      | progress             |   0  | 2.5KB    | No (no user msg) | No                 |
| 6 empty  | unknown  | file-history-snapshot|   0  | 236-12KB | No (no user msg) | No                 |

### Origin markers

- **VS Code sessions** start with `queue-operation` (operation: "dequeue") as the first event
- **CLI sessions** start with `file-history-snapshot` (older versions) or `progress` (v2.1.42+)
- Both share `userType: "external"`, differ in `version` field

## What `sessions-index.json` does (and doesn't do)

Neither client reads `sessions-index.json` for `/resume` display. Both scan `.jsonl` files directly via `readdirSync()`. The index appears to be legacy or used for other purposes (possibly desktop app, analytics, or future features).

The sync tool correctly maintains the index but it has no practical effect on session discovery.

## What the sync tool does

The PHP script at `claude-code-session-sync/script/claude-code-session-sync.php`:
- Scans all project directories, finds `.jsonl` files not in `sessions-index.json`
- Extracts metadata (prompt, timestamps, message count, git branch)
- Dry-run by default, `--write` to update indexes
- Found 73 orphaned sessions across 10 projects
- Useful as a diagnostic/audit tool, but does NOT fix the `/resume` visibility problem

## Possible fixes

1. **File a bug** — The 16KB buffer (`AyR = 16384`) in `by8` is too small for VS Code sessions with images. Increasing it to 128KB or 256KB would fix most cases. Better: read lines incrementally until a user message is found, rather than using a fixed buffer.

2. **Workaround: add custom titles** — The `ky8` filter checks `!firstPrompt && !customTitle`. Sessions with a `customTitle` event in the `.jsonl` file would bypass the prompt extraction entirely. Could write a script to append `{"type":"custom-title","customTitle":"...","sessionId":"..."}` to VS Code sessions.

3. **Workaround: strip images from first message** — Not practical since the .jsonl is append-only.

## GitHub issues

- **#25984** — our bug report for the 16KB buffer truncation (filed with root cause analysis)
- #25032 — same symptom, attributed to stale `sessions-index.json` (wrong cause)
- #22723 — Desktop app not showing CLI sessions (different bug)
- #12819 — VS Code `/resume` empty (possibly related, closed stale)
- #13872 — VS Code session files not persisted (different bug)
