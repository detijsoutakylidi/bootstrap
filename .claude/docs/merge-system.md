# Merge System

## Overview

Config file updates use intelligent merging instead of blind overwrite. The user chooses between Skip, Overwrite, and Merge. Merge groups changes into categories with bulk actions.

## merge_lines_config

For line-based files like gitignore. Pure bash, no external dependencies.

**Groups:**
1. **Identical** — same line in both → auto-keep, show count
2. **Local-only** — user added → Keep all / Keep selectively / Drop all
3. **New from setup** — incoming → Merge all / Merge selectively / Skip all

Comments (`# ...`) and empty lines are excluded from comparison but preserved in output.

**Bash 3.2 note:** Uses `_in_list()` helper with linear search instead of associative arrays (`declare -A`), because macOS ships bash 3.2.

## merge_json_config

For JSON/JSONC files. Uses embedded Python 3 (~190 lines in bootstrap.sh heredoc).

### JSONC Parser

Strips `//` comments respecting string boundaries (won't break URLs like `https://...`) and removes trailing commas. Outputs clean JSON for `json.loads()`.

### Object Mode (`merge_type="object"`)

Used for: `settings.json`, flat config files.

Compares top-level keys:
1. **Same key + same value** → auto-keep
2. **Same key + different value** → Local all / Setup all / Each
3. **Local-only keys** → Keep all / Selectively / Drop all
4. **New keys from setup** → Merge all / Selectively / Skip all

Output preserves setup key order, then appends local-only keys.

### Array Mode (`merge_type="array:field1,field2"`)

Used for: `keybindings.json` (`array:key,command`), CodexBar config (`array:id`).

Each array entry is identified by a tuple of field values. Same 4-group logic as object mode, applied per entry.

### Testing

`MERGE_TEST=1` env var makes `ask()` read from stdin instead of `/dev/tty`, enabling automated tests. 15 test cases in `test-merge.sh` cover all merge modes, JSONC parsing, and combined scenarios.

### Limitations

- Merged output is clean JSON (no comments). JSONC comments from the source file are lost after merge. Next overwrite from setup restores them.
- Nested object values are compared as serialized JSON. No recursive key-level diffing within nested values — they're treated as atomic.
