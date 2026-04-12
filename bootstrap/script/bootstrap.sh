#!/usr/bin/env bash

#
# Unified macOS bootstrap.
#
# Installs system tools and configures user environment in one pass.
#
# Install from anywhere:
#   bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh)
#   bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --install
#   bash <(curl -fsSL https://djtl.cz/gh/bootstrap.sh) --configure
#
# Run specific sections:
#   bash bootstrap.sh --vscode                   # VS Code only (install + configure)
#   bash bootstrap.sh --configure --terminal     # configure terminal only
#   bash bootstrap.sh --install --base --vscode  # install base + vscode only
#
# Or run locally:
#   bash bootstrap/script/bootstrap.sh [--install | --configure] [--base] [--vscode] [--claude] [--terminal]
#

set -euo pipefail

# When piped via `curl | bash`, bash reads stdin incrementally — exec < /dev/tty
# would discard the unread portion of the script. Use `bash -c "$(curl ...)"` or
# `bash <(curl ...)` instead, so bash loads the full script into memory first.
# Then this redirect safely switches stdin to the terminal for interactive prompts.
if [[ ! -t 0 ]]; then
  exec < /dev/tty
fi

REPO_RAW_URL="https://raw.githubusercontent.com/detijsoutakylidi/bootstrap/main/bootstrap/script/config"

# Detect local config dir (works when run from repo checkout)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo "")"
LOCAL_CONFIG_DIR="$SCRIPT_DIR/config"

# Temp dir for downloaded config files — cleaned up on exit
TMPDIR_BOOTSTRAP="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BOOTSTRAP"' EXIT

# Fetch a config file — local if available, otherwise download from GitHub
# Usage: config_path=$(fetch_config "vscode/settings.json")
fetch_config() {
  local subpath="$1"
  if [[ -n "$SCRIPT_DIR" && -f "$LOCAL_CONFIG_DIR/$subpath" ]]; then
    echo "$LOCAL_CONFIG_DIR/$subpath"
    return
  fi
  local dest="$TMPDIR_BOOTSTRAP/$subpath"
  mkdir -p "$(dirname "$dest")"
  if curl -fsSL "$REPO_RAW_URL/$subpath" -o "$dest"; then
    echo "$dest"
  else
    echo ""
  fi
}

blue=$'\033[1;34m'
green=$'\033[1;32m'
yellow=$'\033[1;33m'
red=$'\033[1;31m'
reset=$'\033[0m'

info()  { echo "${blue}▸${reset} $1"; }
ok()    { echo "${green}✔${reset} $1"; }
skip()  { echo "${yellow}⊘${reset} $1"; }
fail()  { echo "${red}✘${reset} $1"; }
section()  { echo; echo "${reset}⎯ $1 ⎯${reset}"; }

# ─── Merge helpers ─────────────────────────────────────────

# Merge two line-based config files (e.g., gitignore)
# Usage: merge_lines_config <src_path> <dst_path> <label>
merge_lines_config() {
  local src="$1" dst="$2" label="$3"

  if [[ ! -f "$dst" ]]; then
    cp "$src" "$dst"
    ok "$label installed → $dst"
    return
  fi

  if diff -q "$src" "$dst" &>/dev/null; then
    skip "$label already up to date"
    return
  fi

  info "$label differs from setup version."
  read -rp "$(echo "${blue}▸${reset} [S]kip / [O]verwrite / [M]erge? [s/o/m] ")" choice
  case "$choice" in
    [oO])
      cp "$src" "$dst"
      ok "$label overwritten"
      ;;
    [mM])
      # Collect non-empty, non-comment lines (bash 3.2 compatible)
      local_lines=()
      while IFS= read -r line; do local_lines+=("$line"); done < <(grep -vE '^$|^#' "$dst" 2>/dev/null || true)
      setup_lines=()
      while IFS= read -r line; do setup_lines+=("$line"); done < <(grep -vE '^$|^#' "$src" 2>/dev/null || true)

      # Classify entries using linear search (no associative arrays)
      _in_list() { local needle="$1"; shift; for item; do [[ "$item" == "$needle" ]] && return 0; done; return 1; }

      common=(); local_only=(); new_lines=()
      for e in "${local_lines[@]}"; do
        if _in_list "$e" "${setup_lines[@]}"; then common+=("$e"); else local_only+=("$e"); fi
      done
      for e in "${setup_lines[@]}"; do
        _in_list "$e" "${local_lines[@]}" || new_lines+=("$e")
      done

      MERGED=()

      # 1. Identical — auto-keep
      if [[ ${#common[@]} -gt 0 ]]; then
        skip "${#common[@]} entries identical — keeping"
        MERGED+=("${common[@]}")
      fi

      # 2. Local-only — ask
      if [[ ${#local_only[@]} -gt 0 ]]; then
        echo
        info "${#local_only[@]} entries only in local:"
        for e in "${local_only[@]}"; do echo "  $e"; done
        read -rp "$(echo "${blue}▸${reset} [K]eep all / keep [S]electively / [D]rop all? [k/s/d] ")" ans
        case "$ans" in
          [dD]) ;;
          [sS])
            for e in "${local_only[@]}"; do
              read -rp "$(echo "${blue}▸${reset}   Keep \"$e\"? [Y/n] ")" c
              [[ ! "$c" =~ ^[Nn]$ ]] && MERGED+=("$e")
            done
            ;;
          *) MERGED+=("${local_only[@]}") ;;
        esac
      fi

      # 3. New from setup — ask
      if [[ ${#new_lines[@]} -gt 0 ]]; then
        echo
        info "${#new_lines[@]} new entries from setup:"
        for e in "${new_lines[@]}"; do echo "  $e"; done
        read -rp "$(echo "${blue}▸${reset} [M]erge all / merge [S]electively / s[K]ip all? [m/s/k] ")" ans
        case "$ans" in
          [kK]) ;;
          [sS])
            for e in "${new_lines[@]}"; do
              read -rp "$(echo "${blue}▸${reset}   Add \"$e\"? [Y/n] ")" c
              [[ ! "$c" =~ ^[Nn]$ ]] && MERGED+=("$e")
            done
            ;;
          *) MERGED+=("${new_lines[@]}") ;;
        esac
      fi

      printf '%s\n' "${MERGED[@]}" > "$dst"
      ok "$label merged"
      ;;
    *)
      skip "Kept existing $label"
      ;;
  esac
}

# Merge two JSON/JSONC config files with intelligent key-based diffing
# Usage: merge_json_config <src_content> <dst_path> <label> <merge_type>
#   merge_type: "object" for flat JSON objects (settings.json, codexbar)
#               "array:field1,field2" for arrays identified by fields (keybindings)
merge_json_config() {
  local src_content="$1" dst="$2" label="$3" merge_type="${4:-object}"

  if [[ ! -f "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"
    echo "$src_content" > "$dst"
    ok "$label installed"
    return
  fi

  if diff -q <(echo "$src_content") "$dst" &>/dev/null; then
    skip "$label already up to date"
    return
  fi

  info "$label differs from setup version."
  read -rp "$(echo "${blue}▸${reset} [S]kip / [O]verwrite / [M]erge? [s/o/m] ")" choice
  case "$choice" in
    [oO])
      echo "$src_content" > "$dst"
      ok "$label overwritten"
      ;;
    [mM])
      local tmp_setup="$TMPDIR_BOOTSTRAP/merge_setup_$$"
      local tmp_output="$TMPDIR_BOOTSTRAP/merge_output_$$"
      echo "$src_content" > "$tmp_setup"

      MERGE_SETUP="$tmp_setup" MERGE_LOCAL="$dst" MERGE_OUTPUT="$tmp_output" \
        MERGE_TYPE="$merge_type" python3 <<'PYEOF'
import os, sys, json, re

B = '\033[1;34m'
G = '\033[1;32m'
Y = '\033[1;33m'
R = '\033[0m'

def strip_jsonc(text):
    lines = []
    for line in text.split('\n'):
        out, in_str, esc = [], False, False
        for i, c in enumerate(line):
            if esc:
                out.append(c); esc = False; continue
            if c == '\\' and in_str:
                out.append(c); esc = True; continue
            if c == '"':
                in_str = not in_str
            if not in_str and c == '/' and i + 1 < len(line) and line[i + 1] == '/':
                break
            out.append(c)
        lines.append(''.join(out))
    return re.sub(r',(\s*[}\]])', r'\1', '\n'.join(lines))

def parse(text):
    return json.loads(strip_jsonc(text))

def ask(prompt):
    tty = sys.stdin if os.environ.get('MERGE_TEST') else open('/dev/tty')
    sys.stdout.write(f"{B}\u25b8{R} {prompt}")
    sys.stdout.flush()
    ans = tty.readline().strip()
    if tty is not sys.stdin:
        tty.close()
    return ans

def fmt(v):
    s = json.dumps(v)
    return s if len(s) <= 80 else s[:77] + '...'

def merge_objects(local, setup):
    local_keys, setup_keys = set(local), set(setup)
    both = local_keys & setup_keys
    same = sorted(k for k in both if json.dumps(local[k], sort_keys=True) == json.dumps(setup[k], sort_keys=True))
    diff = sorted(k for k in both if k not in set(same))
    only_local = sorted(local_keys - setup_keys)
    only_setup = sorted(setup_keys - local_keys)
    keep = {}

    if same:
        print(f"{Y}\u2298{R} {len(same)} settings identical \u2014 keeping")
        for k in same: keep[k] = local[k]

    if diff:
        print(f"\n{B}\u25b8{R} {len(diff)} settings have different values:")
        for k in diff:
            print(f"  {k}:")
            print(f"    local: {fmt(local[k])}")
            print(f"    setup: {fmt(setup[k])}")
        ans = ask("[L]ocal all / [S]etup all / choose [E]ach? [l/s/e] ").lower()
        for k in diff:
            if ans == 's':
                keep[k] = setup[k]
            elif ans == 'e':
                print(f"  {k}: local={fmt(local[k])} \u2192 setup={fmt(setup[k])}")
                c = ask(f"  Use [L]ocal / [S]etup? [l/s] ").lower()
                keep[k] = setup[k] if c == 's' else local[k]
            else:
                keep[k] = local[k]

    if only_local:
        print(f"\n{B}\u25b8{R} {len(only_local)} settings only in local:")
        for k in only_local: print(f"  {k}: {fmt(local[k])}")
        ans = ask("[K]eep all / keep [S]electively / [D]rop all? [k/s/d] ").lower()
        for k in only_local:
            if ans == 'd': continue
            elif ans == 's':
                c = ask(f"  Keep {k}? [Y/n] ").lower()
                if c != 'n': keep[k] = local[k]
            else: keep[k] = local[k]

    if only_setup:
        print(f"\n{B}\u25b8{R} {len(only_setup)} new settings from setup:")
        for k in only_setup: print(f"  {k}: {fmt(setup[k])}")
        ans = ask("[M]erge all / merge [S]electively / s[K]ip all? [m/s/k] ").lower()
        for k in only_setup:
            if ans == 'k': continue
            elif ans == 's':
                c = ask(f"  Add {k}? [Y/n] ").lower()
                if c != 'n': keep[k] = setup[k]
            else: keep[k] = setup[k]

    # Preserve order: setup keys first, then local-only
    ordered = {}
    for k in setup:
        if k in keep: ordered[k] = keep[k]
    for k in local:
        if k in keep and k not in ordered: ordered[k] = keep[k]
    return ordered

def merge_arrays(local, setup, id_fields):
    def eid(e): return tuple(e.get(f, '') for f in id_fields)
    def label(e): return ' + '.join(str(e.get(f, '')) for f in id_fields if e.get(f))

    local_map = {eid(e): e for e in local}
    setup_map = {eid(e): e for e in setup}
    local_ids, setup_ids = set(local_map), set(setup_map)
    both = local_ids & setup_ids
    same = sorted(k for k in both if json.dumps(local_map[k], sort_keys=True) == json.dumps(setup_map[k], sort_keys=True))
    diff = sorted(k for k in both if k not in set(same))
    only_local = sorted(local_ids - setup_ids)
    only_setup = sorted(setup_ids - local_ids)
    keep = {}

    if same:
        print(f"{Y}\u2298{R} {len(same)} entries identical \u2014 keeping")
        for k in same: keep[k] = local_map[k]

    if diff:
        print(f"\n{B}\u25b8{R} {len(diff)} entries have different values:")
        for k in diff:
            print(f"  {label(local_map[k])}:")
            print(f"    local: {fmt(local_map[k])}")
            print(f"    setup: {fmt(setup_map[k])}")
        ans = ask("[L]ocal all / [S]etup all / choose [E]ach? [l/s/e] ").lower()
        for k in diff:
            if ans == 's': keep[k] = setup_map[k]
            elif ans == 'e':
                c = ask(f"  {label(local_map[k])}: [L]ocal / [S]etup? [l/s] ").lower()
                keep[k] = setup_map[k] if c == 's' else local_map[k]
            else: keep[k] = local_map[k]

    if only_local:
        print(f"\n{B}\u25b8{R} {len(only_local)} entries only in local:")
        for k in only_local: print(f"  {label(local_map[k])}")
        ans = ask("[K]eep all / keep [S]electively / [D]rop all? [k/s/d] ").lower()
        for k in only_local:
            if ans == 'd': continue
            elif ans == 's':
                c = ask(f"  Keep {label(local_map[k])}? [Y/n] ").lower()
                if c != 'n': keep[k] = local_map[k]
            else: keep[k] = local_map[k]

    if only_setup:
        print(f"\n{B}\u25b8{R} {len(only_setup)} new entries from setup:")
        for k in only_setup: print(f"  {label(setup_map[k])}")
        ans = ask("[M]erge all / merge [S]electively / s[K]ip all? [m/s/k] ").lower()
        for k in only_setup:
            if ans == 'k': continue
            elif ans == 's':
                c = ask(f"  Add {label(setup_map[k])}? [Y/n] ").lower()
                if c != 'n': keep[k] = setup_map[k]
            else: keep[k] = setup_map[k]

    # Preserve order: setup first, then local-only
    result, seen = [], set()
    for e in setup:
        k = eid(e)
        if k in keep and k not in seen: result.append(keep[k]); seen.add(k)
    for e in local:
        k = eid(e)
        if k in keep and k not in seen: result.append(keep[k]); seen.add(k)
    return result

def main():
    setup_path = os.environ['MERGE_SETUP']
    local_path = os.environ['MERGE_LOCAL']
    output_path = os.environ['MERGE_OUTPUT']
    merge_type = os.environ.get('MERGE_TYPE', 'object')

    with open(setup_path) as f: setup_data = parse(f.read())
    with open(local_path) as f: local_data = parse(f.read())

    if json.dumps(local_data, sort_keys=True) == json.dumps(setup_data, sort_keys=True):
        print(f"{G}\u2714{R} Semantically identical (formatting differs) \u2014 normalizing")
        with open(output_path, 'w') as f:
            json.dump(setup_data, f, indent=4, ensure_ascii=False)
            f.write('\n')
        return

    if merge_type == 'object':
        result = merge_objects(local_data, setup_data)
    elif merge_type.startswith('array:'):
        result = merge_arrays(local_data, setup_data, merge_type[6:].split(','))
    else:
        print(f"Unknown merge type: {merge_type}", file=sys.stderr)
        sys.exit(1)

    with open(output_path, 'w') as f:
        json.dump(result, f, indent=4, ensure_ascii=False)
        f.write('\n')

if __name__ == '__main__':
    main()
PYEOF

      if [[ -f "$tmp_output" ]]; then
        cp "$tmp_output" "$dst"
        ok "$label merged"
      else
        fail "Merge failed for $label"
      fi
      rm -f "$tmp_setup" "$tmp_output"
      ;;
    *)
      skip "Kept existing $label"
      ;;
  esac
}

# ─── Argument parsing ───────────────────────────────────────

PHASE_INSTALL=false
PHASE_CONFIGURE=false
SEC_BASE=false
SEC_VSCODE=false
SEC_VSCODE_ASSOC=false
SEC_CLAUDE=false
SEC_TERMINAL=false
SEC_HERD=false
SECTION_SPECIFIED=false
EXTENDED=false

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
      fail "Unknown option: $1"
      echo "Usage: bash bootstrap.sh [--install | --configure] [--base] [--vscode] [--vscode-assoc] [--claude] [--terminal] [--herd] [--extended]"
      exit 1
      ;;
  esac
  shift
done

# Default: all sections when none specified
if ! $SECTION_SPECIFIED; then
  SEC_BASE=true; SEC_VSCODE=true; SEC_CLAUDE=true; SEC_TERMINAL=true
fi

# Default: auto-detect phase when neither specified
if ! $PHASE_INSTALL && ! $PHASE_CONFIGURE; then
  if dseditgroup -o checkmember -m "$(whoami)" admin &>/dev/null; then
    PHASE_INSTALL=true
    PHASE_CONFIGURE=true
  else
    info "Non-admin user detected — running in configure-only mode."
    info "For system installs, run from an admin account: bash bootstrap.sh --install"
    echo
    PHASE_CONFIGURE=true
  fi
fi

do_install()   { $PHASE_INSTALL; }
do_configure() { $PHASE_CONFIGURE; }
do_base()      { $SEC_BASE; }
do_vscode()    { $SEC_VSCODE; }
do_vscode_assoc() { $SEC_VSCODE_ASSOC; }
do_claude()    { $SEC_CLAUDE; }
do_terminal()  { $SEC_TERMINAL; }
do_herd()      { $SEC_HERD; }

# ═══════════════════════════════════════════════════════════════
# INSTALL PHASE
# ═══════════════════════════════════════════════════════════════

install_devbase() {
  # ─── Xcode Command Line Tools ───
  section "Xcode Command Line Tools"

  if xcode-select -p &>/dev/null; then
    skip "Already installed: $(xcode-select -p)"
  else
    info "Installing Xcode Command Line Tools…"
    info "A macOS dialog will pop up — click Install and wait."
    xcode-select --install

    until xcode-select -p &>/dev/null; do
      sleep 5
    done
    ok "Xcode Command Line Tools installed"
  fi

  # ─── Rosetta 2 (Apple Silicon only) ───
  section "Rosetta 2"

  arch=$(uname -m)
  if [[ "$arch" != "arm64" ]]; then
    skip "Not Apple Silicon ($arch) — Rosetta not needed"
  elif /usr/bin/pgrep -q oahd; then
    skip "Already installed"
  else
    info "Installing Rosetta 2…"
    softwareupdate --install-rosetta --agree-to-license
    ok "Rosetta 2 installed"
  fi

  # ─── Homebrew ───
  section "Homebrew"

  if command -v brew &>/dev/null; then
    skip "Already installed: $(brew --version | head -1)"
  else
    info "Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    ok "Homebrew installed"
  fi

  # ─── Git ───
  section "Git"

  if command -v git &>/dev/null; then
    skip "Already installed: $(git --version)"
  else
    info "Installing Git via Homebrew…"
    brew install git
    ok "Git installed"
  fi

  # ─── jq ───
  section "jq"

  if command -v jq &>/dev/null; then
    skip "Already installed: $(jq --version)"
  else
    info "Installing jq via Homebrew…"
    brew install jq
    ok "jq installed"
  fi

  # ─── ripgrep ───
  section "ripgrep"

  if command -v rg &>/dev/null; then
    skip "Already installed: $(rg --version | head -1)"
  else
    info "Installing ripgrep via Homebrew…"
    brew install ripgrep
    ok "ripgrep installed"
  fi

  # ─── GitHub CLI ───
  section "GitHub CLI"

  if command -v gh &>/dev/null; then
    skip "Already installed: $(gh --version | head -1)"
  else
    info "Installing GitHub CLI via Homebrew…"
    brew install gh
    ok "GitHub CLI installed"
  fi
}

install_vscode() {
  # ─── VS Code app ───
  section "VS Code"

  if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ] || command -v code &>/dev/null || brew list --cask visual-studio-code &>/dev/null 2>&1; then
    skip "VS Code already installed"
  else
    info "Installing VS Code…"
    brew install --cask visual-studio-code
    ok "VS Code installed"
  fi

  # ─── duti ───
  section "duti"

  if command -v duti &>/dev/null; then
    skip "Already installed"
  else
    info "Installing duti (for file associations)…"
    brew install duti
    ok "duti installed"
  fi
}

install_claude() {
  # ─── Claude Code ───
  section "Claude Code"

  # Detect and offer to remove Homebrew formula version (conflicts with native installer)
  # Note: `brew list claude` matches the Claude Desktop cask — check formula only
  if brew list --formula claude-code &>/dev/null 2>&1 || [[ -f "/opt/homebrew/bin/claude" ]]; then
    BREW_VER=$(/opt/homebrew/bin/claude --version 2>/dev/null || echo "unknown")
    info "Homebrew version detected: claude $BREW_VER"
    read -rp "$(echo "${blue}▸${reset} Remove Homebrew version in favour of native installer? [y/N] ")" answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
      brew uninstall --formula claude-code 2>/dev/null || true
      ok "Homebrew claude removed"
      hash -r  # refresh command cache
    fi
  fi

  # Helper: ensure ~/.local/bin is in PATH
  _ensure_claude_path() {
    export PATH="$HOME/.local/bin:$PATH"
    SHELL_RC="$HOME/.zshrc"
    if ! grep -q '\.local/bin' "$SHELL_RC" 2>/dev/null; then
      echo '' >> "$SHELL_RC"
      echo '# Claude Code' >> "$SHELL_RC"
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_RC"
      ok "Added ~/.local/bin to PATH (~/.zshrc)"
    fi
  }

  # Check specifically for native install, not any claude in PATH
  if [[ -f "$HOME/.local/bin/claude" ]]; then
    _ensure_claude_path
    skip "Already installed: claude $(claude --version 2>/dev/null || echo '?')"
  else
    info "Installing Claude Code via native installer…"
    if curl -fsSL https://claude.ai/install.sh | bash; then
      ok "Claude Code installed"
      [[ -f "$HOME/.local/bin/claude" ]] && _ensure_claude_path
    else
      fail "Claude Code install failed"
    fi
  fi

  # ─── Claude Desktop ───
  section "Claude Desktop"

  if [[ -d "/Applications/Claude.app" ]] || brew list --cask claude &>/dev/null 2>&1; then
    skip "Already installed: Claude.app"
  else
    info "Installing Claude Desktop via Homebrew…"
    if brew install --cask claude; then
      ok "Claude Desktop installed"
    else
      fail "Claude Desktop install failed"
    fi
  fi

  # ─── CodexBar ───
  section "CodexBar"

  if [[ -d "/Applications/CodexBar.app" ]] || brew list --cask codexbar &>/dev/null 2>&1; then
    skip "Already installed: CodexBar.app"
  else
    info "Tapping steipete/tap…"
    brew tap steipete/tap 2>/dev/null || true
    info "Installing CodexBar via Homebrew…"
    if brew install --cask steipete/tap/codexbar; then
      ok "CodexBar installed"
    else
      fail "CodexBar install failed"
    fi
  fi
}

install_herd() {
  # ─── Laravel Herd ───
  section "Laravel Herd"

  if [[ -d "/Applications/Herd.app" ]] || command -v herd &>/dev/null; then
    skip "Already installed: Herd.app"
  else
    info "Installing Laravel Herd via Homebrew…"
    brew install --cask herd
    ok "Herd installed"
    info "Open Herd.app once to complete initial setup, then re-run bootstrap."
  fi

  # ─── .private TLD wildcard ───
  section ".private TLD"

  DNSMASQ_CONF="$HOME/Library/Application Support/Herd/config/dnsmasq/dnsmasq.conf"
  RESOLVER_FILE="/etc/resolver/private"
  PRIVATE_ENTRY="address=/.private/127.0.0.1"

  # Add .private to Herd's dnsmasq (wildcard — all *.private → 127.0.0.1)
  if [[ ! -f "$DNSMASQ_CONF" ]]; then
    fail "Herd dnsmasq.conf not found — open Herd.app first to initialize"
  elif grep -qF "$PRIVATE_ENTRY" "$DNSMASQ_CONF" 2>/dev/null; then
    skip ".private already in dnsmasq.conf"
  else
    echo "$PRIVATE_ENTRY" >> "$DNSMASQ_CONF"
    ok "Added *.private → 127.0.0.1 to dnsmasq.conf"
  fi

  # Create macOS resolver so .private queries go to Herd's dnsmasq
  if [[ -f "$RESOLVER_FILE" ]] && grep -q "nameserver 127.0.0.1" "$RESOLVER_FILE" 2>/dev/null; then
    skip "/etc/resolver/private already configured"
  else
    echo "nameserver 127.0.0.1" | sudo tee "$RESOLVER_FILE" > /dev/null
    ok "Created /etc/resolver/private"
  fi

  # Restart Herd to pick up the new dnsmasq config
  if pgrep -q "Herd" 2>/dev/null; then
    info "Restarting Herd to apply .private TLD config…"
    osascript -e 'tell application "Herd" to quit' 2>/dev/null || true
    sleep 2
    open -a "Herd"
    ok "Herd restarted"
  fi
}

# ═══════════════════════════════════════════════════════════════
# CONFIGURE PHASE
# ═══════════════════════════════════════════════════════════════

configure_devbase() {
  section "Git global config"

  GITIGNORE_SRC="$(fetch_config "git/gitignore_global")"
  GITIGNORE_DST="$HOME/.gitignore_global"

  if [[ -z "$GITIGNORE_SRC" || ! -f "$GITIGNORE_SRC" ]]; then
    fail "gitignore_global not found (local or remote)"
  else
    merge_lines_config "$GITIGNORE_SRC" "$GITIGNORE_DST" "Global gitignore"
  fi
  git config --global core.excludesFile "$GITIGNORE_DST"

  # Allow file:// transport for git submodules (local library sharing via knihovnik).
  # Blocked by default since Git 2.38.1 (CVE-2022-39253) to prevent exfiltration
  # via malicious .gitmodules in cloned repos. Safe for our use — we only add
  # submodules from our own local projects.
  git config --global protocol.file.allow always
}

configure_terminal() {
  # ─── Terminal.app Pro profile ───
  section "Terminal.app Pro profile"

  PRO_TERMINAL="$(fetch_config "terminal/Pro.terminal")"
  if [[ -z "$PRO_TERMINAL" || ! -f "$PRO_TERMINAL" ]]; then
    fail "Pro.terminal not found (local or remote)"
    return
  fi

  PROFILE_CHANGED=$(python3 -c "
import plistlib, subprocess, sys

with open('$PRO_TERMINAL', 'rb') as f:
    new_profile = plistlib.load(f)

try:
    result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
    prefs = plistlib.loads(result.stdout)
    current_profile = prefs.get('Window Settings', {}).get('Pro')
except:
    current_profile = None

if current_profile is None:
    print('new')
elif current_profile == new_profile:
    print('same')
else:
    print('different')
")

  import_profile() {
    python3 -c "
import plistlib, subprocess, os

with open('$PRO_TERMINAL', 'rb') as f:
    profile = plistlib.load(f)

try:
    result = subprocess.run(['defaults', 'export', 'com.apple.Terminal', '-'], capture_output=True)
    prefs = plistlib.loads(result.stdout)
except:
    prefs = {}

if 'Window Settings' not in prefs:
    prefs['Window Settings'] = {}
prefs['Window Settings']['Pro'] = profile

with open('/tmp/terminal-import.plist', 'wb') as f:
    plistlib.dump(prefs, f)
subprocess.run(['defaults', 'import', 'com.apple.Terminal', '/tmp/terminal-import.plist'], check=True)
os.remove('/tmp/terminal-import.plist')
"
    defaults write com.apple.Terminal "Default Window Settings" -string "Pro"
    defaults write com.apple.Terminal "Startup Window Settings" -string "Pro"
  }

  case "$PROFILE_CHANGED" in
    new)
      info "Importing Pro profile..."
      import_profile
      ok "Pro profile imported and set as default"
      ;;
    same)
      skip "Pro profile already up to date"
      ;;
    different)
      info "Pro profile differs from setup version."
      read -rp "$(echo "${blue}▸${reset} [S]kip / [O]verwrite? [s/o] ")" choice
      case "$choice" in
        [oO])
          import_profile
          ok "Pro profile overwritten"
          ;;
        *)
          skip "Kept existing Pro profile"
          ;;
      esac
      ;;
  esac

  # ─── Shell prompt ───
  section "Shell prompt"

  SHELL_RC="$HOME/.zshrc"
  PROMPT_LINE="PROMPT='%1~ % '"

  if grep -q "^PROMPT=" "$SHELL_RC" 2>/dev/null; then
    CURRENT=$(grep "^PROMPT=" "$SHELL_RC")
    if [ "$CURRENT" = "$PROMPT_LINE" ]; then
      skip "Prompt already set"
    else
      info "Prompt already configured as: $CURRENT"
      read -rp "$(echo "${blue}▸${reset} Replace with: $PROMPT_LINE? [y/N] ")" answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        sed -i '' "s|^PROMPT=.*|$PROMPT_LINE|" "$SHELL_RC"
        ok "Prompt updated"
      else
        skip "Kept existing prompt"
      fi
    fi
  else
    echo '' >> "$SHELL_RC"
    echo '# prompt' >> "$SHELL_RC"
    echo "$PROMPT_LINE" >> "$SHELL_RC"
    ok "Prompt added to ~/.zshrc"
  fi
}

configure_vscode() {
  VSCODE_CONFIG_DIR="$HOME/Library/Application Support/Code/User"

  # ─── code CLI in PATH ───
  section "VS Code CLI"

  VSCODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
  if command -v code &>/dev/null; then
    skip "'code' already in PATH"
  elif [ -d "$VSCODE_BIN" ]; then
    export PATH="$PATH:$VSCODE_BIN"

    SHELL_RC="$HOME/.zshrc"
    if ! grep -q "Visual Studio Code" "$SHELL_RC" 2>/dev/null; then
      echo '' >> "$SHELL_RC"
      echo '# VS Code CLI' >> "$SHELL_RC"
      echo 'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"' >> "$SHELL_RC"
      ok "'code' added to PATH permanently (~/.zshrc)"
    fi
  else
    fail "VS Code not found — install it first (bash bootstrap.sh --install)"
    return
  fi

  # ─── Projects directory ───
  section "Projects directory"

  PROJECTS_DIR="$HOME/Projects"
  if [ -d "$PROJECTS_DIR" ]; then
    skip "Projects directory exists: $PROJECTS_DIR"
  else
    read -rp "$(echo "${blue}▸${reset} Projects directory (default: ~/Projects): ")" CUSTOM_DIR
    PROJECTS_DIR="${CUSTOM_DIR:-$HOME/Projects}"
    PROJECTS_DIR="${PROJECTS_DIR/#\~/$HOME}"
    if [ -d "$PROJECTS_DIR" ]; then
      skip "Projects directory exists: $PROJECTS_DIR"
    else
      info "Creating $PROJECTS_DIR..."
      mkdir -p "$PROJECTS_DIR"
      ok "Created $PROJECTS_DIR"
    fi
  fi

  # ─── Essential extensions ───
  section "Essential extensions"

  INSTALLED_EXTENSIONS=$(code --list-extensions 2>/dev/null || true)

  install_extension() {
    local ext="$1"
    local name="$2"
    if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext}$"; then
      skip "$name already installed"
    else
      info "Installing $name..."
      code --install-extension "$ext" --force
      ok "$name installed"
    fi
  }

  install_extension "anthropic.claude-code"           "Claude Code"
  install_extension "catppuccin.catppuccin-vsc"       "Catppuccin Theme"
  install_extension "alefragnani.project-manager"     "Project Manager"
  install_extension "mrmlnc.vscode-duplicate"         "Duplicate Action"
  install_extension "natizyskunk.sftp"                "SFTP"
  install_extension "johnpapa.vscode-peacock"          "Peacock"
  install_extension "zaaack.markdown-editor"           "Markdown Editor"
  install_extension "tomoki1207.pdf"                   "PDF Viewer"

  # ─── Optional extensions (--extended) ───
  if $EXTENDED; then
    section "Optional extensions"

    ask_install() {
      local ext="$1"
      local name="$2"
      if echo "$INSTALLED_EXTENSIONS" | grep -qi "^${ext}$"; then
        skip "$name already installed"
        return
      fi
      read -rp "$(echo "${blue}▸${reset} Install $name? [y/N] ")" answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        code --install-extension "$ext" --force
        ok "$name installed"
      fi
    }

    # ─── PHP tools ───
    ask_install "bmewburn.vscode-intelephense-client"   "Intelephense (PHP) — VS Code"

    if ! command -v intelephense &>/dev/null; then
      read -rp "$(echo "${blue}▸${reset} Install Intelephense CLI (for Claude Code LSP)? [y/N] ")" answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        npm install -g intelephense
        ok "Intelephense CLI installed"
      fi
    else
      skip "Intelephense CLI already installed"
    fi

    if command -v claude &>/dev/null; then
      if ! claude plugin list 2>/dev/null | grep -q "php-lsp"; then
        read -rp "$(echo "${blue}▸${reset} Install php-lsp Claude Code plugin? [y/N] ")" answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
          claude plugin install php-lsp@claude-plugins-official
          ok "php-lsp plugin installed"
        fi
      else
        skip "php-lsp plugin already installed"
      fi
    fi

    # ─── Other extensions ───
    ask_install "britesnow.vscode-toggle-quotes"         "Toggle Quotes"
    ask_install "hashicorp.terraform"                    "Terraform"
    ask_install "highagency.pencildev"                   "Pencil"
    ask_install "1password.op-vscode"                    "1Password"
  fi

  # ─── Config files ───
  section "Config files"

  mkdir -p "$VSCODE_CONFIG_DIR"

  SETTINGS_SRC="$(fetch_config "vscode/settings.json")"
  if [[ -n "$SETTINGS_SRC" && -f "$SETTINGS_SRC" ]]; then
    RENDERED_SETTINGS=$(sed -e "s|__HOME__|$HOME|g" \
        -e "s|__PROJECTS_DIR__|$PROJECTS_DIR|g" \
        "$SETTINGS_SRC")
    merge_json_config "$RENDERED_SETTINGS" "$VSCODE_CONFIG_DIR/settings.json" "settings.json" "object"
  else
    fail "settings.json not found (local or remote)"
  fi

  KEYBINDINGS_SRC="$(fetch_config "vscode/keybindings.json")"
  if [[ -n "$KEYBINDINGS_SRC" && -f "$KEYBINDINGS_SRC" ]]; then
    KEYBINDINGS_CONTENT=$(cat "$KEYBINDINGS_SRC")
    merge_json_config "$KEYBINDINGS_CONTENT" "$VSCODE_CONFIG_DIR/keybindings.json" "keybindings.json" "array:key,command"
  else
    fail "keybindings.json not found (local or remote)"
  fi

  # ─── File associations ───
  configure_vscode_assoc
}

configure_vscode_assoc() {
  section "File associations"

  if ! command -v duti &>/dev/null; then
    fail "duti not found — install it first (bash bootstrap.sh --install)"
    return
  fi

  VSCODE_BUNDLE="com.microsoft.VSCode"

  set_file_association() {
    local identifier="$1"
    local label="$2"
    local type="$3"

    # Check current handler — duti -d returns bundle ID, duti -x returns app name
    local current_bundle=""
    if [ "$type" = "ext" ]; then
      # duti -x output: line 1 = app name, line 3 = bundle ID
      current_bundle=$(duti -x "${identifier#.}" 2>/dev/null | sed -n '3p' || true)
      if [ -z "$current_bundle" ]; then
        current_bundle=$(duti -x "${identifier#.}" 2>/dev/null | head -1 || true)
      fi
    else
      current_bundle=$(duti -d "$identifier" 2>/dev/null | head -1 || true)
    fi

    # Filter out error responses (-1, numeric codes, empty)
    if [ -z "$current_bundle" ] || [ "$current_bundle" = "null" ] || [[ "$current_bundle" =~ ^-?[0-9]+$ ]]; then
      current_bundle=""
    fi

    # Check if VS Code is already the handler
    if [ -n "$current_bundle" ] && echo "$current_bundle" | grep -qiE "com.microsoft.VSCode|Visual Studio Code"; then
      skip "$label already opens in VS Code"
      return
    fi

    # If there's a current handler, ask before changing
    if [ -n "$current_bundle" ]; then
      local display_name
      display_name=$(duti -x "${label#.}" 2>/dev/null | head -1) || true
      # Filter error responses from display too
      if [ -z "$display_name" ] || [[ "$display_name" =~ ^-?[0-9]+$ ]]; then
        display_name="$current_bundle"
      fi
      read -rp "$(echo "${blue}▸${reset} $label currently opens in: $display_name. Set to VS Code? [y/N] ")" answer
      if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        return
      fi
    fi

    duti -s "$VSCODE_BUNDLE" "$identifier" all
    ok "$label → VS Code"
  }

  # UTI-based associations
  set_file_association "public.json"                    ".json"       "uti"
  set_file_association "public.xml"                     ".xml"        "uti"
  set_file_association "com.netscape.javascript-source" ".js"         "uti"
  set_file_association "org.w3.webvtt"                  ".vtt"        "uti"

  # Extension-based associations
  set_file_association ".md"       ".md"       "ext"
  set_file_association ".jsonl"    ".jsonl"    "ext"
  set_file_association ".srt"      ".srt"      "ext"
  set_file_association ".pub"      ".pub"      "ext"
  set_file_association ".tf"       ".tf"       "ext"
  set_file_association ".tfstate"  ".tfstate"  "ext"
}

configure_claude() {
  section "Claude ecosystem"

  # ─── Chrome extension ───
  read -rp "$(echo "${blue}▸${reset} Open Chrome Web Store to install Claude extension? [y/N] ")" answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    open 'https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn' 2>/dev/null || true
    ok "Chrome Web Store opened — install manually"
  else
    skip "Skipped Chrome extension"
  fi

  # ─── CodexBar config ───
  section "CodexBar config"

  CODEXBAR_SRC="$(fetch_config "codexbar/config.json")"
  CODEXBAR_DST="$HOME/.codexbar/config.json"

  if [[ -z "$CODEXBAR_SRC" || ! -f "$CODEXBAR_SRC" ]]; then
    fail "codexbar/config.json not found (local or remote)"
  else
    merge_json_config "$(cat "$CODEXBAR_SRC")" "$CODEXBAR_DST" "CodexBar config" "array:id"
  fi

  # ─── CodexBar preferences ───
  section "CodexBar preferences"

  CODEXBAR_PLIST="$(fetch_config "codexbar/defaults.plist")"

  if [[ -z "$CODEXBAR_PLIST" || ! -f "$CODEXBAR_PLIST" ]]; then
    fail "codexbar/defaults.plist not found (local or remote)"
  else
    defaults import com.steipete.codexbar "$CODEXBAR_PLIST"
    ok "CodexBar preferences merged"
  fi

  # ─── Claude Code company rules ───
  section "Claude Code company rules"

  DJTL_SRC="$(fetch_config "claude/CLAUDE-djtl.md")"
  DJTL_DST="$HOME/.claude/CLAUDE-djtl.md"

  if [[ -z "$DJTL_SRC" || ! -f "$DJTL_SRC" ]]; then
    fail "claude/CLAUDE-djtl.md not found (local or remote)"
  else
    mkdir -p "$HOME/.claude"
    cp "$DJTL_SRC" "$DJTL_DST"
    ok "CLAUDE-djtl.md deployed → $DJTL_DST"
  fi

  # ─── Global CLAUDE.md ───
  section "Global CLAUDE.md"

  GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"
  if [[ ! -f "$GLOBAL_CLAUDE" ]]; then
    cat > "$GLOBAL_CLAUDE" << 'CLAUDEEOF'
@CLAUDE-djtl.md

# Personal

TODO: Add your personal preferences and communication style here.
CLAUDEEOF
    ok "Created ~/.claude/CLAUDE.md with @CLAUDE-djtl.md inclusion"
  elif ! grep -q "@CLAUDE-djtl.md" "$GLOBAL_CLAUDE" 2>/dev/null; then
    info "~/.claude/CLAUDE.md exists but does not include @CLAUDE-djtl.md"
    info "Adding @CLAUDE-djtl.md inclusion at the top…"
    TMPFILE="$(mktemp)"
    echo "@CLAUDE-djtl.md" > "$TMPFILE"
    echo "" >> "$TMPFILE"
    cat "$GLOBAL_CLAUDE" >> "$TMPFILE"
    mv "$TMPFILE" "$GLOBAL_CLAUDE"
    ok "Added @CLAUDE-djtl.md to ~/.claude/CLAUDE.md"
  else
    skip "~/.claude/CLAUDE.md already includes @CLAUDE-djtl.md"
  fi

  # ─── Claude Code settings ───
  section "Claude Code settings"

  CLAUDE_SETTINGS="$HOME/.claude/settings.json"
  if [[ -f "$CLAUDE_SETTINGS" ]] && command -v jq &>/dev/null; then
    CLEANUP_DAYS=$(jq -r '.cleanupPeriodDays // empty' "$CLAUDE_SETTINGS" 2>/dev/null)
    if [[ -n "$CLEANUP_DAYS" && "$CLEANUP_DAYS" -ge 90000 ]] 2>/dev/null; then
      skip "Session retention already set (${CLEANUP_DAYS} days)"
    else
      info "Claude Code deletes session history after 30 days by default."
      info "Sessions contain full conversation context — useful for auditing,"
      info "resuming work, and extracting knowledge from past sessions."
      info "Recommended: set cleanupPeriodDays to 90000 (~246 years) to prevent loss."
      read -rp "$(echo "${blue}▸${reset} Set session retention to 90000 days? [Y/n] ")" answer
      if [[ ! "$answer" =~ ^[Nn]$ ]]; then
        jq '.cleanupPeriodDays = 90000' "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
        ok "cleanupPeriodDays set to 90000"
      else
        skip "Kept default session retention"
      fi
    fi
  elif [[ ! -f "$CLAUDE_SETTINGS" ]] && command -v jq &>/dev/null; then
    info "Claude Code deletes session history after 30 days by default."
    info "Sessions contain full conversation context — useful for auditing,"
    info "resuming work, and extracting knowledge from past sessions."
    info "Recommended: set cleanupPeriodDays to 90000 (~246 years) to prevent loss."
    read -rp "$(echo "${blue}▸${reset} Set session retention to 90000 days? [Y/n] ")" answer
    if [[ ! "$answer" =~ ^[Nn]$ ]]; then
      mkdir -p "$HOME/.claude"
      echo '{"cleanupPeriodDays": 90000}' | jq . > "$CLAUDE_SETTINGS"
      ok "Created ~/.claude/settings.json with cleanupPeriodDays = 90000"
    else
      skip "Kept default session retention"
    fi
  else
    info "jq not available — skipping Claude Code settings check"
  fi

  # ─── new-project script ───
  section "new-project script"

  NEWPROJ_SRC="$(fetch_config "claude/new-project.sh")"
  if [[ -z "$NEWPROJ_SRC" || ! -f "$NEWPROJ_SRC" ]]; then
    fail "claude/new-project.sh not found (local or remote)"
  else
    SCRIPTS_DST="$HOME/.claude/scripts"
    mkdir -p "$SCRIPTS_DST"
    cp "$NEWPROJ_SRC" "$SCRIPTS_DST/new-project.sh"
    ok "new-project.sh deployed → $SCRIPTS_DST/new-project.sh"

    # Copy templates alongside the script
    for tmpl in project-en.md personal-en.md; do
      TMPL_SRC="$(fetch_config "claude/$tmpl")"
      if [[ -n "$TMPL_SRC" && -f "$TMPL_SRC" ]]; then
        cp "$TMPL_SRC" "$SCRIPTS_DST/$tmpl"
      fi
    done
    ok "Templates deployed alongside new-project.sh"

    # Symlink into projects directory for easy access
    if [[ -n "$PROJECTS_DIR" && -d "$PROJECTS_DIR" ]]; then
      ln -sf "$SCRIPTS_DST/new-project.sh" "$PROJECTS_DIR/new-project.sh"
      ok "Symlinked new-project.sh → $PROJECTS_DIR/new-project.sh"
    fi
    info "Usage: cd $PROJECTS_DIR && bash new-project.sh <name> [description]"
  fi

  # ─── Manual steps ───
  section "Manual steps needed"
  echo

  MANUAL_STEPS=0

  if command -v claude &>/dev/null && claude auth status &>/dev/null 2>&1; then
    skip "Claude Code already authenticated"
  else
    info "Run: claude login                       → authenticate Claude Code"
    MANUAL_STEPS=$((MANUAL_STEPS + 1))
  fi

  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    skip "GitHub CLI already authenticated"
  else
    info "Run: gh auth login                      → authenticate GitHub CLI"
    MANUAL_STEPS=$((MANUAL_STEPS + 1))
  fi

  if [[ -d "/Applications/Claude.app" ]]; then
    skip "Claude Desktop installed"
  else
    info "Open Claude.app                         → sign in with your account"
    MANUAL_STEPS=$((MANUAL_STEPS + 1))
  fi

  info "Claude Desktop → Settings → Connectors  → enable Claude in Chrome connector"
  MANUAL_STEPS=$((MANUAL_STEPS + 1))

  if [[ "$MANUAL_STEPS" -eq 0 ]]; then
    ok "All steps already completed!"
  fi
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════

PHASES=""
$PHASE_INSTALL && PHASES="${PHASES}install "
$PHASE_CONFIGURE && PHASES="${PHASES}configure "
SECTIONS=""
$SEC_BASE && SECTIONS="${SECTIONS}base "
$SEC_VSCODE && SECTIONS="${SECTIONS}vscode "
$SEC_VSCODE_ASSOC && SECTIONS="${SECTIONS}vscode-assoc "
$SEC_CLAUDE && SECTIONS="${SECTIONS}claude "
$SEC_TERMINAL && SECTIONS="${SECTIONS}terminal "
$SEC_HERD && SECTIONS="${SECTIONS}herd "

# Offer Herd when running with --extended and it wasn't explicitly requested
if $EXTENDED && ! $SEC_HERD && do_install; then
  read -rp "$(echo "${blue}▸${reset} Install Laravel Herd (.private TLD for local services)? [y/N] ")" answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    SEC_HERD=true
    SECTIONS="${SECTIONS}herd "
  fi
fi

# Version stamp — update before each push
BOOTSTRAP_BUILD="260412-1813"
# Append git hash when running from local checkout
if [[ -n "$SCRIPT_DIR" ]] && command -v git &>/dev/null && (cd "$SCRIPT_DIR" && git rev-parse --git-dir &>/dev/null); then
  GIT_HASH=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null) || true
  [[ -n "$GIT_HASH" ]] && BOOTSTRAP_BUILD="$BOOTSTRAP_BUILD $GIT_HASH"
fi

echo
echo "┌───────────────────────────────────────────────┐"
echo "│  macOS Bootstrap ($BOOTSTRAP_BUILD)"
echo "│  phase: ${PHASES% }"
echo "│  sections: ${SECTIONS% }"
echo "└───────────────────────────────────────────────┘"
echo
read -rp "$(echo "${blue}▸${reset} Run bootstrap? [Y/n] ")" CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
  info "Aborted."
  exit 0
fi

if do_install; then
  echo
  echo "══════════════════════════════════════"
  echo "  INSTALL PHASE (system-level)"
  echo "══════════════════════════════════════"

  if do_base;   then install_devbase; fi
  if do_vscode; then install_vscode; fi
  if do_claude; then install_claude; fi
  if do_herd;   then install_herd; fi
fi

if do_configure; then
  echo
  echo "══════════════════════════════════════"
  echo "  CONFIGURE PHASE (user-level)"
  echo "══════════════════════════════════════"

  if do_base;       then configure_devbase;      fi
  if do_terminal;   then configure_terminal;    fi
  if do_vscode;     then configure_vscode;      fi
  if do_vscode_assoc; then configure_vscode_assoc; fi
  if do_claude;     then configure_claude;      fi
fi

echo
section "Done"
echo
ok "Bootstrap complete (phase: ${PHASES% }, sections: ${SECTIONS% })"
