#!/usr/bin/env bash
#
# Tests for merge_json_config Python helper and merge_lines_config.
# Run: bash bootstrap/script/test-merge.sh
#

set -uo pipefail
cd "$(dirname "$0")"

PASS=0
FAIL=0
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

green=$'\033[1;32m'
red=$'\033[1;31m'
reset=$'\033[0m'

assert_json_eq() {
  local label="$1" expected="$2" actual="$3"
  # Compare as sorted JSON to ignore key order
  local exp_norm act_norm
  exp_norm=$(echo "$expected" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin), sort_keys=True))")
  act_norm=$(python3 -c "import sys,json; print(json.dumps(json.load(open('$actual')), sort_keys=True))")
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

assert_lines_eq() {
  local label="$1" expected="$2" actual="$3"
  local exp_sorted act_sorted
  exp_sorted=$(echo "$expected" | sort)
  act_sorted=$(sort "$actual")
  if [[ "$exp_sorted" == "$act_sorted" ]]; then
    echo "${green}PASS${reset}: $label"
    ((PASS++))
  else
    echo "${red}FAIL${reset}: $label"
    echo "  expected: $exp_sorted"
    echo "  actual:   $act_sorted"
    ((FAIL++))
  fi
}

# Extract the Python merge script from bootstrap.sh
sed -n '/^import os, sys, json, re$/,/^if __name__/p' bootstrap.sh > "$TMPDIR/merge.py"
# Add main() call
echo "    main()" >> "$TMPDIR/merge.py"

# Make ask() read from stdin instead of /dev/tty for testing
# No patching needed — MERGE_TEST=1 makes ask() read from stdin instead of /dev/tty

# ─── Test: Object merge — identical files ───
echo '{"a": 1, "b": 2}' > "$TMPDIR/setup.json"
echo '{"a": 1, "b": 2}' > "$TMPDIR/local.json"
MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" < /dev/null 2>&1 | grep -q "identical" || true
assert_json_eq "object: identical files" '{"a": 1, "b": 2}' "$TMPDIR/out.json"

# ─── Test: Object merge — local-only keys (keep all via 'k') ───
echo '{"a": 1}' > "$TMPDIR/setup.json"
echo '{"a": 1, "extra": true}' > "$TMPDIR/local.json"
echo "k" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: local-only keep all" '{"a": 1, "extra": true}' "$TMPDIR/out.json"

# ─── Test: Object merge — local-only keys (drop all via 'd') ───
echo '{"a": 1}' > "$TMPDIR/setup.json"
echo '{"a": 1, "extra": true}' > "$TMPDIR/local.json"
echo "d" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: local-only drop all" '{"a": 1}' "$TMPDIR/out.json"

# ─── Test: Object merge — new keys from setup (merge all via 'm') ───
echo '{"a": 1, "new_key": "hello"}' > "$TMPDIR/setup.json"
echo '{"a": 1}' > "$TMPDIR/local.json"
echo "m" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: new keys merge all" '{"a": 1, "new_key": "hello"}' "$TMPDIR/out.json"

# ─── Test: Object merge — new keys (skip all via 'k') ───
echo '{"a": 1, "new_key": "hello"}' > "$TMPDIR/setup.json"
echo '{"a": 1}' > "$TMPDIR/local.json"
echo "k" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: new keys skip all" '{"a": 1}' "$TMPDIR/out.json"

# ─── Test: Object merge — different values (keep local via 'l') ───
echo '{"a": 1, "b": "setup"}' > "$TMPDIR/setup.json"
echo '{"a": 1, "b": "local"}' > "$TMPDIR/local.json"
echo "l" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: diff values keep local" '{"a": 1, "b": "local"}' "$TMPDIR/out.json"

# ─── Test: Object merge — different values (use setup via 's') ───
echo '{"a": 1, "b": "setup"}' > "$TMPDIR/setup.json"
echo '{"a": 1, "b": "local"}' > "$TMPDIR/local.json"
echo "s" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: diff values use setup" '{"a": 1, "b": "setup"}' "$TMPDIR/out.json"

# ─── Test: Object merge — combined scenario ───
# setup: a=1, b="new", c="setup"
# local: a=1, b="old", d="user"
# Answers: 's' for diff (use setup b), 'k' for local-only (keep d), 'm' for new (add c)
cat > "$TMPDIR/setup.json" << 'EOF'
{"a": 1, "b": "new", "c": "setup"}
EOF
cat > "$TMPDIR/local.json" << 'EOF'
{"a": 1, "b": "old", "d": "user"}
EOF
printf 's\nk\nm\n' | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "object: combined scenario" '{"a": 1, "b": "new", "c": "setup", "d": "user"}' "$TMPDIR/out.json"

# ─── Test: JSONC parsing — comments and trailing commas ───
cat > "$TMPDIR/setup.json" << 'EOF'
{
    // This is a comment
    "a": 1,
    "b": "https://example.com/path", // trailing comment
}
EOF
echo '{"a": 1, "b": "https://example.com/path"}' > "$TMPDIR/local.json"
MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="object" \
  python3 "$TMPDIR/merge.py" < /dev/null > /dev/null 2>&1
assert_json_eq "JSONC: comments and trailing commas" '{"a": 1, "b": "https://example.com/path"}' "$TMPDIR/out.json"

# ─── Test: Array merge — keybindings identical ───
cat > "$TMPDIR/setup.json" << 'EOF'
[{"key": "cmd+e", "command": "focus"}]
EOF
cat > "$TMPDIR/local.json" << 'EOF'
[{"key": "cmd+e", "command": "focus"}]
EOF
MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="array:key,command" \
  python3 "$TMPDIR/merge.py" < /dev/null > /dev/null 2>&1
assert_json_eq "array: identical keybindings" '[{"key": "cmd+e", "command": "focus"}]' "$TMPDIR/out.json"

# ─── Test: Array merge — local-only entries (keep all) ───
cat > "$TMPDIR/setup.json" << 'EOF'
[{"key": "cmd+e", "command": "focus"}]
EOF
cat > "$TMPDIR/local.json" << 'EOF'
[{"key": "cmd+e", "command": "focus"}, {"key": "cmd+x", "command": "custom"}]
EOF
echo "k" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="array:key,command" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "array: local-only keep" '[{"key": "cmd+e", "command": "focus"}, {"key": "cmd+x", "command": "custom"}]' "$TMPDIR/out.json"

# ─── Test: Array merge — new entries from setup (merge all) ───
cat > "$TMPDIR/setup.json" << 'EOF'
[{"key": "cmd+e", "command": "focus"}, {"key": "cmd+n", "command": "new"}]
EOF
cat > "$TMPDIR/local.json" << 'EOF'
[{"key": "cmd+e", "command": "focus"}]
EOF
echo "m" | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="array:key,command" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "array: new entries merge" '[{"key": "cmd+e", "command": "focus"}, {"key": "cmd+n", "command": "new"}]' "$TMPDIR/out.json"

# ─── Test: Array merge (CodexBar) — by id field ───
cat > "$TMPDIR/setup.json" << 'EOF'
[{"id": "claude", "enabled": true, "source": "cli"}, {"id": "cursor", "enabled": false}]
EOF
cat > "$TMPDIR/local.json" << 'EOF'
[{"id": "claude", "enabled": true, "source": "cli"}, {"id": "gemini", "enabled": true}]
EOF
printf 'k\nm\n' | MERGE_TEST=1 MERGE_SETUP="$TMPDIR/setup.json" MERGE_LOCAL="$TMPDIR/local.json" \
  MERGE_OUTPUT="$TMPDIR/out.json" MERGE_TYPE="array:id" \
  python3 "$TMPDIR/merge.py" > /dev/null 2>&1
assert_json_eq "array:id: codexbar merge" \
  '[{"id": "claude", "enabled": true, "source": "cli"}, {"id": "cursor", "enabled": false}, {"id": "gemini", "enabled": true}]' \
  "$TMPDIR/out.json"

# ─── Test: merge_lines_config — needs bash functions ───
# Source colors + merge_lines_config from bootstrap.sh (up to argument parsing)
eval "$(sed -n '59,165p' bootstrap.sh)"

# Test: identical files
printf '.DS_Store\n.vscode/\n' > "$TMPDIR/src_gitignore"
printf '.DS_Store\n.vscode/\n' > "$TMPDIR/dst_gitignore"
TMPDIR_BOOTSTRAP="$TMPDIR" merge_lines_config "$TMPDIR/src_gitignore" "$TMPDIR/dst_gitignore" "test-gitignore" > /dev/null 2>&1
assert_lines_eq "lines: identical" ".DS_Store
.vscode/" "$TMPDIR/dst_gitignore"

# Test: new file (dst doesn't exist)
rm -f "$TMPDIR/dst_new"
printf '.DS_Store\n.env\n' > "$TMPDIR/src_new"
merge_lines_config "$TMPDIR/src_new" "$TMPDIR/dst_new" "test-new" > /dev/null 2>&1
assert_lines_eq "lines: new install" ".DS_Store
.env" "$TMPDIR/dst_new"

echo
echo "═══════════════════════"
echo "  Results: ${green}$PASS passed${reset}, ${red}$FAIL failed${reset}"
echo "═══════════════════════"

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
