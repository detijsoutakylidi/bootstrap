#!/usr/bin/env bash
#
# Tests for bootstrap.sh logic — argument parsing, config detection,
# install idempotency, configure decisions, JSONC edge cases, herd section.
#
# Run: bash bootstrap/script/test-bootstrap.sh
#

set -uo pipefail
cd "$(dirname "$0")"

PASS=0
FAIL=0
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

green=$'\033[1;32m'
red=$'\033[1;31m'
dim=$'\033[2m'
reset=$'\033[0m'

# ─── Assertion helpers ─────────────────────────────────────

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "${green}PASS${reset}: $label"
    ((PASS++))
  else
    echo "${red}FAIL${reset}: $label"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    ((FAIL++))
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    echo "${green}PASS${reset}: $label"
    ((PASS++))
  else
    echo "${red}FAIL${reset}: $label"
    echo "  expected to contain: $needle"
    echo "  actual: $haystack"
    ((FAIL++))
  fi
}

assert_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    echo "${green}PASS${reset}: $label"
    ((PASS++))
  else
    echo "${red}FAIL${reset}: $label"
    echo "  expected NOT to contain: $needle"
    echo "  actual: $haystack"
    ((FAIL++))
  fi
}

assert_json_eq() {
  local label="$1" expected="$2" actual_file="$3"
  local exp_norm act_norm
  exp_norm=$(echo "$expected" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), sort_keys=True))" 2>/dev/null) || true
  act_norm=$(python3 -c "import sys,json; print(json.dumps(json.load(open('$actual_file')), sort_keys=True))" 2>/dev/null) || true
  if [[ "$exp_norm" == "$act_norm" ]]; then
    echo "${green}PASS${reset}: $label"
    ((PASS++))
  else
    echo "${red}FAIL${reset}: $label"
    echo "  expected: $exp_norm"
    echo "  actual:   $act_norm"
    ((FAIL++))
  fi
}

# ─── Mock helpers ──────────────────────────────────────────

MOCK_BIN="$TMPDIR/mock_bin"
MOCK_HOME="$TMPDIR/mock_home"
mkdir -p "$MOCK_BIN" "$MOCK_HOME"

create_mock() {
  local cmd="$1" exit_code="${2:-0}" stdout="${3:-}"
  cat > "$MOCK_BIN/$cmd" << MOCKEOF
#!/bin/bash
echo "$stdout"
exit $exit_code
MOCKEOF
  chmod +x "$MOCK_BIN/$cmd"
}

reset_mocks() {
  rm -f "$MOCK_BIN"/*
  rm -rf "$MOCK_HOME"/*
}

# ─── Extract Python merge script ──────────────────────────

sed -n '/^import os, sys, json, re$/,/^if __name__/p' bootstrap.sh > "$TMPDIR/merge.py"
echo "    main()" >> "$TMPDIR/merge.py"

# Helper: run JSONC through the parser and output clean JSON
parse_jsonc() {
  local input="$1" output="$2"
  echo "$input" > "$TMPDIR/_jsonc_input.json"
  python3 -c "
import sys, os
sys.path.insert(0, '$TMPDIR')
exec(open('$TMPDIR/merge.py').read().split('if __name__')[0])
import json
with open('$TMPDIR/_jsonc_input.json') as f:
    result = parse(f.read())
with open('$output', 'w') as f:
    json.dump(result, f, sort_keys=True)
" 2>&1
}

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── A. JSONC Parser Edge Cases ───${reset}"
echo

# A1: URL with // inside string
parse_jsonc '{"url": "https://example.com/path"}' "$TMPDIR/a1.json"
assert_json_eq "A1: URL with // inside string" '{"url": "https://example.com/path"}' "$TMPDIR/a1.json"

# A2: Escaped quotes
parse_jsonc '{"msg": "say \"hello\" world"}' "$TMPDIR/a2.json"
assert_json_eq "A2: escaped quotes in string" '{"msg": "say \"hello\" world"}' "$TMPDIR/a2.json"

# A3: URL + trailing comment
parse_jsonc '{"url": "https://x.com"} // comment' "$TMPDIR/a3.json"
assert_json_eq "A3: URL preserved, comment stripped" '{"url": "https://x.com"}' "$TMPDIR/a3.json"

# A4: Empty structures
parse_jsonc '{}' "$TMPDIR/a4a.json"
assert_json_eq "A4a: empty object" '{}' "$TMPDIR/a4a.json"
parse_jsonc '[]' "$TMPDIR/a4b.json"
assert_json_eq "A4b: empty array" '[]' "$TMPDIR/a4b.json"

# A5: Commented-out key
parse_jsonc '{
    // "commented": "value",
    "real": 1
}' "$TMPDIR/a5.json"
assert_json_eq "A5: commented-out key ignored" '{"real": 1}' "$TMPDIR/a5.json"

# A6: Array with comment + trailing comma
parse_jsonc '{
    "arr": [
        1,
        // skip
        2,
    ]
}' "$TMPDIR/a6.json"
assert_json_eq "A6: array with comment + trailing comma" '{"arr": [1, 2]}' "$TMPDIR/a6.json"

# A7: Backslash paths
parse_jsonc '{"path": "C:\\Users\\test"}' "$TMPDIR/a7.json"
assert_json_eq "A7: backslash paths preserved" '{"path": "C:\\Users\\test"}' "$TMPDIR/a7.json"

# A8: Nested trailing commas
parse_jsonc '{"a": {"b": 1,}, "c": [1, 2,],}' "$TMPDIR/a8.json"
assert_json_eq "A8: nested trailing commas" '{"a": {"b": 1}, "c": [1, 2]}' "$TMPDIR/a8.json"

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── B. Argument Parsing ───${reset}"
echo

# Create argument parsing test wrapper
cat > "$TMPDIR/parse_args.sh" << 'PARSEEOF'
#!/bin/bash
PHASE_INSTALL=false; PHASE_CONFIGURE=false
SEC_BASE=false; SEC_VSCODE=false; SEC_VSCODE_ASSOC=false
SEC_CLAUDE=false; SEC_TERMINAL=false; SEC_HERD=false
SECTION_SPECIFIED=false; EXTENDED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)   PHASE_INSTALL=true ;;
    --configure) PHASE_CONFIGURE=true ;;
    --base)      SEC_BASE=true; SECTION_SPECIFIED=true ;;
    --vscode)    SEC_VSCODE=true; SECTION_SPECIFIED=true ;;
    --vscode-assoc) SEC_VSCODE_ASSOC=true; SECTION_SPECIFIED=true ;;
    --claude)    SEC_CLAUDE=true; SECTION_SPECIFIED=true ;;
    --terminal)  SEC_TERMINAL=true; SECTION_SPECIFIED=true ;;
    --herd)      SEC_HERD=true; SECTION_SPECIFIED=true ;;
    --extended)  EXTENDED=true ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if ! $SECTION_SPECIFIED; then
  SEC_BASE=true; SEC_VSCODE=true; SEC_CLAUDE=true; SEC_TERMINAL=true
fi

echo "I=$PHASE_INSTALL C=$PHASE_CONFIGURE B=$SEC_BASE V=$SEC_VSCODE CL=$SEC_CLAUDE T=$SEC_TERMINAL H=$SEC_HERD E=$EXTENDED"
PARSEEOF
chmod +x "$TMPDIR/parse_args.sh"

# B1: No flags — all defaults, herd excluded
result=$(bash "$TMPDIR/parse_args.sh")
assert_contains "B1: defaults include base" "$result" "B=true"
assert_contains "B1: defaults include vscode" "$result" "V=true"
assert_contains "B1: defaults include claude" "$result" "CL=true"
assert_contains "B1: defaults include terminal" "$result" "T=true"
assert_contains "B1: herd NOT in defaults" "$result" "H=false"

# B2: --install only
result=$(bash "$TMPDIR/parse_args.sh" --install)
assert_contains "B2: install phase set" "$result" "I=true"
assert_contains "B2: configure not set" "$result" "C=false"

# B3: --configure only
result=$(bash "$TMPDIR/parse_args.sh" --configure)
assert_contains "B3: install not set" "$result" "I=false"
assert_contains "B3: configure set" "$result" "C=true"

# B4: both phases
result=$(bash "$TMPDIR/parse_args.sh" --install --configure)
assert_contains "B4: both phases" "$result" "I=true"
assert_contains "B4: both phases" "$result" "C=true"

# B5: --vscode only
result=$(bash "$TMPDIR/parse_args.sh" --vscode)
assert_contains "B5: vscode only" "$result" "V=true"
assert_contains "B5: base off" "$result" "B=false"
assert_contains "B5: claude off" "$result" "CL=false"

# B6: --base --claude
result=$(bash "$TMPDIR/parse_args.sh" --base --claude)
assert_contains "B6: base on" "$result" "B=true"
assert_contains "B6: claude on" "$result" "CL=true"
assert_contains "B6: vscode off" "$result" "V=false"

# B7: --herd explicit
result=$(bash "$TMPDIR/parse_args.sh" --herd)
assert_contains "B7: herd on" "$result" "H=true"
assert_contains "B7: base off" "$result" "B=false"

# B8: --extended
result=$(bash "$TMPDIR/parse_args.sh" --extended)
assert_contains "B8: extended on" "$result" "E=true"
assert_contains "B8: defaults still on" "$result" "B=true"

# B9: unknown flag
result=$(bash "$TMPDIR/parse_args.sh" --bogus 2>&1) || true
assert_contains "B9: unknown flag error" "$result" "Unknown option"

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── C. fetch_config ───${reset}"
echo

# Set up fetch_config function
TMPDIR_BOOTSTRAP="$TMPDIR/bootstrap_tmp"
mkdir -p "$TMPDIR_BOOTSTRAP"

eval "$(sed -n '44,57p' bootstrap.sh)"

# C1: Local file exists
SCRIPT_DIR="$TMPDIR"
LOCAL_CONFIG_DIR="$TMPDIR/local_config"
mkdir -p "$LOCAL_CONFIG_DIR/test"
echo "local content" > "$LOCAL_CONFIG_DIR/test/file.txt"
result=$(fetch_config "test/file.txt")
assert_eq "C1: local file returned" "$LOCAL_CONFIG_DIR/test/file.txt" "$result"

# C2: Local missing, curl succeeds — create mock curl
LOCAL_CONFIG_DIR="$TMPDIR/nonexistent"
create_mock curl 0 ""
# Mock curl that actually creates the file
cat > "$MOCK_BIN/curl" << 'CURLEOF'
#!/bin/bash
# Find -o flag and write to that file
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) echo "downloaded" > "$2"; shift ;;
  esac
  shift
done
exit 0
CURLEOF
chmod +x "$MOCK_BIN/curl"
REPO_RAW_URL="https://example.com"
result=$(PATH="$MOCK_BIN:$PATH" fetch_config "test/file.txt")
assert_contains "C2: downloaded path returned" "$result" "$TMPDIR_BOOTSTRAP"

# C3: Both fail
SCRIPT_DIR=""
cat > "$MOCK_BIN/curl" << 'CURLEOF'
#!/bin/bash
exit 1
CURLEOF
chmod +x "$MOCK_BIN/curl"
result=$(PATH="$MOCK_BIN:$PATH" fetch_config "test/missing.txt")
assert_eq "C3: empty on failure" "" "$result"

# C4: SCRIPT_DIR empty (curl mode), curl succeeds
SCRIPT_DIR=""
cat > "$MOCK_BIN/curl" << 'CURLEOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) echo "remote" > "$2"; shift ;;
  esac
  shift
done
exit 0
CURLEOF
chmod +x "$MOCK_BIN/curl"
result=$(PATH="$MOCK_BIN:$PATH" fetch_config "test/remote.txt")
assert_contains "C4: curl mode returns path" "$result" "$TMPDIR_BOOTSTRAP"

reset_mocks

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── D. Install Detection ───${reset}"
echo

# D1: command -v brew — found
create_mock brew 0 "Homebrew 4.0"
result=$(PATH="$MOCK_BIN:$PATH" bash -c 'command -v brew &>/dev/null && echo SKIP || echo INSTALL')
assert_eq "D1: brew found → skip" "SKIP" "$result"

# D2: command -v brew — not found
reset_mocks
result=$(PATH="$MOCK_BIN:/usr/bin:/bin" bash -c 'command -v brew &>/dev/null && echo SKIP || echo INSTALL')
assert_eq "D2: brew not found → install" "INSTALL" "$result"

# D3: VS Code detection — command -v code
create_mock code 0 ""
result=$(PATH="$MOCK_BIN:$PATH" bash -c 'command -v code &>/dev/null && echo SKIP || echo INSTALL')
assert_eq "D3: VS Code via command -v" "SKIP" "$result"

# D4a: Claude Code — brew formula detected
create_mock brew 0 ""
cat > "$MOCK_BIN/brew" << 'EOF'
#!/bin/bash
[[ "$1" == "list" && "$2" == "--formula" && "$3" == "claude-code" ]] && exit 0
exit 1
EOF
chmod +x "$MOCK_BIN/brew"
result=$(PATH="$MOCK_BIN:$PATH" bash -c 'brew list --formula claude-code &>/dev/null 2>&1 && echo DETECTED || echo NOT_FOUND')
assert_eq "D4a: brew formula claude-code detected" "DETECTED" "$result"

# D4b: Claude Code — native install detected
mkdir -p "$MOCK_HOME/.local/bin"
touch "$MOCK_HOME/.local/bin/claude"
result=$([[ -f "$MOCK_HOME/.local/bin/claude" ]] && echo SKIP || echo INSTALL)
assert_eq "D4b: native claude detected" "SKIP" "$result"

# D5: Herd — command -v herd
reset_mocks
create_mock herd 0 ""
result=$(PATH="$MOCK_BIN:$PATH" bash -c 'command -v herd &>/dev/null && echo SKIP || echo INSTALL')
assert_eq "D5: herd detected" "SKIP" "$result"

# D6: Herd — not found
reset_mocks
result=$(PATH="$MOCK_BIN:/usr/bin:/bin" bash -c 'command -v herd &>/dev/null && echo SKIP || echo INSTALL')
assert_eq "D6: herd not found → install" "INSTALL" "$result"

reset_mocks

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── E. Configure Logic ───${reset}"
echo

# ─── File associations (E1-E5) ───

# Source helpers for color output
eval "$(sed -n '59,69p' bootstrap.sh)"
VSCODE_BUNDLE="com.microsoft.VSCode"

# E1: duti returns VS Code bundle ID → skip
cat > "$MOCK_BIN/duti" << 'DUTIEOF'
#!/bin/bash
case "$1" in
  -d) echo "com.microsoft.VSCode" ;;
  -x) printf "Visual Studio Code.app\n/Applications/Visual Studio Code.app\ncom.microsoft.VSCode\n" ;;
  -s) exit 0 ;;
esac
DUTIEOF
chmod +x "$MOCK_BIN/duti"

# Extract set_file_association
eval "$(sed -n '993,1052p' bootstrap.sh)"
result=$(PATH="$MOCK_BIN:$PATH" set_file_association "public.json" ".json" "uti" 2>&1)
assert_contains "E1: VS Code handler → skip" "$result" "already opens in VS Code"

# E2: duti returns -1 → treated as no handler
cat > "$MOCK_BIN/duti" << 'DUTIEOF'
#!/bin/bash
case "$1" in
  -d) echo "-1" ;;
  -x) echo "-1" ;;
  -s) echo "SET:$2:$3" >> /tmp/duti_calls; exit 0 ;;
esac
DUTIEOF
chmod +x "$MOCK_BIN/duti"
rm -f /tmp/duti_calls
result=$(PATH="$MOCK_BIN:$PATH" set_file_association "public.json" ".json" "uti" 2>&1)
assert_not_contains "E2: -1 filtered, no ask prompt" "$result" "Set to VS Code"
# Should proceed to set directly
assert_contains "E2: association set" "$result" "VS Code"

# E3: duti returns numeric error code
cat > "$MOCK_BIN/duti" << 'DUTIEOF'
#!/bin/bash
case "$1" in
  -d) echo "42" ;;
  -x) echo "42" ;;
  -s) exit 0 ;;
esac
DUTIEOF
chmod +x "$MOCK_BIN/duti"
result=$(PATH="$MOCK_BIN:$PATH" set_file_association "public.json" ".json" "uti" 2>&1)
assert_not_contains "E3: numeric error filtered" "$result" "currently opens in"

# E4: Different app, user declines
cat > "$MOCK_BIN/duti" << 'DUTIEOF'
#!/bin/bash
case "$1" in
  -d) echo "com.apple.TextEdit" ;;
  -x) printf "TextEdit.app\n/Applications/TextEdit.app\ncom.apple.TextEdit\n" ;;
  -s) echo "SHOULD_NOT_BE_CALLED" >&2; exit 1 ;;
esac
DUTIEOF
chmod +x "$MOCK_BIN/duti"
result=$(echo "n" | PATH="$MOCK_BIN:$PATH" set_file_association ".md" ".md" "ext" 2>&1)
assert_not_contains "E4: user declined, duti -s not called" "$result" "SHOULD_NOT_BE_CALLED"

# E5: UTI uses duti -d, extension uses duti -x
cat > "$MOCK_BIN/duti" << 'DUTIEOF'
#!/bin/bash
echo "CALLED:$1:$2" >> "$TMPDIR/duti_log"
case "$1" in
  -d) echo "com.microsoft.VSCode" ;;
  -x) printf "Visual Studio Code.app\n/Applications/Visual Studio Code.app\ncom.microsoft.VSCode\n" ;;
  -s) exit 0 ;;
esac
DUTIEOF
chmod +x "$MOCK_BIN/duti"
rm -f "$TMPDIR/duti_log"
PATH="$MOCK_BIN:$PATH" set_file_association "public.json" ".json" "uti" > /dev/null 2>&1
uti_call=$(grep "CALLED:-d:public.json" "$TMPDIR/duti_log" 2>/dev/null | head -1)
assert_eq "E5a: UTI uses duti -d" "CALLED:-d:public.json" "$uti_call"

rm -f "$TMPDIR/duti_log"
PATH="$MOCK_BIN:$PATH" set_file_association ".md" ".md" "ext" > /dev/null 2>&1
ext_call=$(grep "CALLED:-x:md" "$TMPDIR/duti_log" 2>/dev/null | head -1)
assert_eq "E5b: extension uses duti -x" "CALLED:-x:md" "$ext_call"

reset_mocks

# ─── Session retention (E6-E8) ───

# E6: cleanupPeriodDays >= 90000 → skip
mkdir -p "$MOCK_HOME/.claude"
echo '{"cleanupPeriodDays": 99999}' > "$MOCK_HOME/.claude/settings.json"
CLAUDE_SETTINGS="$MOCK_HOME/.claude/settings.json"
CLEANUP_DAYS=$(jq -r '.cleanupPeriodDays // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
result=$([[ -n "$CLEANUP_DAYS" && "$CLEANUP_DAYS" -ge 90000 ]] 2>/dev/null && echo SKIP || echo ASK)
assert_eq "E6: retention >= 90000 → skip" "SKIP" "$result"

# E7: cleanupPeriodDays < 90000 → needs update
echo '{"cleanupPeriodDays": 30}' > "$MOCK_HOME/.claude/settings.json"
CLEANUP_DAYS=$(jq -r '.cleanupPeriodDays // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
result=$([[ -n "$CLEANUP_DAYS" && "$CLEANUP_DAYS" -ge 90000 ]] 2>/dev/null && echo SKIP || echo ASK)
assert_eq "E7: retention < 90000 → ask" "ASK" "$result"

# E8: settings.json missing → create
rm -f "$MOCK_HOME/.claude/settings.json"
result=$([[ -f "$MOCK_HOME/.claude/settings.json" ]] && echo EXISTS || echo MISSING)
assert_eq "E8: settings.json missing detected" "MISSING" "$result"

# ─── CLAUDE.md inclusion (E9-E11) ───

# E9: File missing → would create
rm -f "$MOCK_HOME/.claude/CLAUDE.md"
result=$([[ ! -f "$MOCK_HOME/.claude/CLAUDE.md" ]] && echo CREATE || echo EXISTS)
assert_eq "E9: CLAUDE.md missing → create" "CREATE" "$result"

# E10: File exists without @CLAUDE-djtl.md → prepend
echo "# My rules" > "$MOCK_HOME/.claude/CLAUDE.md"
result=$(grep -q "@CLAUDE-djtl.md" "$MOCK_HOME/.claude/CLAUDE.md" 2>/dev/null && echo HAS_IT || echo MISSING)
assert_eq "E10: CLAUDE.md without inclusion" "MISSING" "$result"

# E11: File already has inclusion → skip
echo -e "@CLAUDE-djtl.md\n\n# My rules" > "$MOCK_HOME/.claude/CLAUDE.md"
result=$(grep -q "@CLAUDE-djtl.md" "$MOCK_HOME/.claude/CLAUDE.md" 2>/dev/null && echo HAS_IT || echo MISSING)
assert_eq "E11: CLAUDE.md with inclusion → skip" "HAS_IT" "$result"

# ─── Terminal prompt (E12-E14) ───

PROMPT_LINE="PROMPT='%1~ % '"

# E12: PROMPT= already set and matches → skip
echo "$PROMPT_LINE" > "$MOCK_HOME/.zshrc"
CURRENT=$(grep "^PROMPT=" "$MOCK_HOME/.zshrc")
result=$([[ "$CURRENT" == "$PROMPT_LINE" ]] && echo SKIP || echo DIFFERENT)
assert_eq "E12: prompt matches → skip" "SKIP" "$result"

# E13: PROMPT= set but different
echo "PROMPT='%~ \$ '" > "$MOCK_HOME/.zshrc"
CURRENT=$(grep "^PROMPT=" "$MOCK_HOME/.zshrc")
result=$([[ "$CURRENT" == "$PROMPT_LINE" ]] && echo SKIP || echo DIFFERENT)
assert_eq "E13: different prompt detected" "DIFFERENT" "$result"

# E14: No PROMPT= in .zshrc
echo "# just a comment" > "$MOCK_HOME/.zshrc"
result=$(grep -q "^PROMPT=" "$MOCK_HOME/.zshrc" 2>/dev/null && echo FOUND || echo NOT_FOUND)
assert_eq "E14: no prompt → append" "NOT_FOUND" "$result"

reset_mocks

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── F. Merge Edge Cases ───${reset}"
echo

# F1: Object merge — empty local
echo '{"a": 1}' > "$TMPDIR/setup.json"
echo '{}' > "$TMPDIR/local.json"
echo "m" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "F1: empty local, merge new" '{"a": 1}' "$TMPDIR/out.json"

# F2: Object merge — empty setup
echo '{}' > "$TMPDIR/setup.json"
echo '{"a": 1}' > "$TMPDIR/local.json"
echo "k" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "F2: empty setup, keep local" '{"a": 1}' "$TMPDIR/out.json"

# F3: Both empty
echo '{}' > "$TMPDIR/setup.json"
echo '{}' > "$TMPDIR/local.json"
MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" < /dev/null > /dev/null 2>&1
assert_json_eq "F3: both empty" '{}' "$TMPDIR/out.json"

# F4: Array — duplicate identity entries
echo '[{"key": "a", "command": "x"}]' > "$TMPDIR/setup.json"
echo '[{"key": "a", "command": "x"}, {"key": "a", "command": "x"}]' > "$TMPDIR/local.json"
MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="array:key,command" \
  python3 "$TMPDIR/merge.py" < /dev/null > /dev/null 2>&1
# Should handle gracefully (dict deduplicates by identity)
result=$(python3 -c "import json; print(len(json.load(open('$TMPDIR/out.json'))))")
assert_eq "F4: duplicate identity handled" "1" "$result"

# F5: All local-only, skip new
echo '{"a": 1}' > "$TMPDIR/setup.json"
echo '{"b": 2, "c": 3}' > "$TMPDIR/local.json"
printf 'k\nk\n' | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "F5: keep local, skip new" '{"b": 2, "c": 3}' "$TMPDIR/out.json"

# F6: Lines — comment-only files
eval "$(sed -n '59,165p' bootstrap.sh)"
printf '# comment1\n# comment2\n' > "$TMPDIR/src_comments"
printf '# other\n' > "$TMPDIR/dst_comments"
# diff will see difference (different comments), but merge finds no actionable lines
# Since files differ, it would prompt — but with no actionable entries, overwrite/skip is the path
result=$(diff -q "$TMPDIR/src_comments" "$TMPDIR/dst_comments" &>/dev/null && echo SAME || echo DIFF)
assert_eq "F6: comment-only files differ in raw" "DIFF" "$result"

# F7: Lines — empty local, new entries added
printf '.DS_Store\n.env\n' > "$TMPDIR/src_lines"
printf '' > "$TMPDIR/dst_lines"
echo "o" | merge_lines_config "$TMPDIR/src_lines" "$TMPDIR/dst_lines" "test" > /dev/null 2>&1
result=$(cat "$TMPDIR/dst_lines")
assert_contains "F7: overwrite adds entries" "$result" ".DS_Store"

# F8: Array — same identity, different values, use setup
echo '[{"key": "a", "command": "x", "args": "new"}]' > "$TMPDIR/setup.json"
echo '[{"key": "a", "command": "x", "args": "old"}]' > "$TMPDIR/local.json"
echo "s" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="array:key,command" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "F8: diff values, use setup" '[{"key": "a", "command": "x", "args": "new"}]' "$TMPDIR/out.json"

# ═══════════════════════════════════════════════════════════
echo
echo "${dim}─── G. Herd Section ───${reset}"
echo

# G1: dnsmasq.conf already has .private entry → skip
mkdir -p "$TMPDIR/herd_config"
echo -e "address=/.test/127.0.0.1\naddress=/.private/127.0.0.1" > "$TMPDIR/herd_config/dnsmasq.conf"
result=$(grep -qF "address=/.private/127.0.0.1" "$TMPDIR/herd_config/dnsmasq.conf" && echo SKIP || echo ADD)
assert_eq "G1: .private in dnsmasq → skip" "SKIP" "$result"

# G2: dnsmasq.conf missing .private → would add
echo "address=/.test/127.0.0.1" > "$TMPDIR/herd_config/dnsmasq.conf"
result=$(grep -qF "address=/.private/127.0.0.1" "$TMPDIR/herd_config/dnsmasq.conf" && echo SKIP || echo ADD)
assert_eq "G2: .private missing → add" "ADD" "$result"

# G3: dnsmasq.conf doesn't exist → fail gracefully
rm -f "$TMPDIR/herd_config/dnsmasq.conf"
result=$([[ -f "$TMPDIR/herd_config/dnsmasq.conf" ]] && echo EXISTS || echo MISSING)
assert_eq "G3: missing dnsmasq.conf detected" "MISSING" "$result"

# G4: resolver file already configured → skip
mkdir -p "$TMPDIR/resolver"
echo "nameserver 127.0.0.1" > "$TMPDIR/resolver/private"
result=$(grep -q "nameserver 127.0.0.1" "$TMPDIR/resolver/private" 2>/dev/null && echo SKIP || echo CREATE)
assert_eq "G4: resolver already configured → skip" "SKIP" "$result"

# G5: resolver file missing → would create
rm -f "$TMPDIR/resolver/private"
result=$([[ -f "$TMPDIR/resolver/private" ]] && grep -q "nameserver 127.0.0.1" "$TMPDIR/resolver/private" 2>/dev/null && echo SKIP || echo CREATE)
assert_eq "G5: resolver missing → create" "CREATE" "$result"

# G6: dnsmasq.conf append preserves existing entries
echo "address=/.test/127.0.0.1" > "$TMPDIR/herd_config/dnsmasq.conf"
echo "address=/.private/127.0.0.1" >> "$TMPDIR/herd_config/dnsmasq.conf"
test_count=$(grep -c "address=" "$TMPDIR/herd_config/dnsmasq.conf")
assert_eq "G6: both entries preserved" "2" "$test_count"

# ═══════════════════════════════════════════════════════════
echo
echo "═══════════════════════════════════"
echo "  Results: ${green}$PASS passed${reset}, ${red}$FAIL failed${reset}"
echo "═══════════════════════════════════"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
