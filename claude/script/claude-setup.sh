#!/usr/bin/env bash

#
# Claude ecosystem bootstrap for macOS.
#
# Prerequisites: run devbase-setup.sh first (Xcode CLT, Homebrew).
#
# Installs: Claude Code (native), Claude Desktop,
# CodexBar, and opens Claude in Chrome extension page.
#

set -euo pipefail

blue=$'\033[1;34m'
green=$'\033[1;32m'
yellow=$'\033[1;33m'
red=$'\033[1;31m'
reset=$'\033[0m'

info()  { echo "${blue}▸${reset} $1"; }
ok()    { echo "${green}✔${reset} $1"; }
skip()  { echo "${yellow}⊘${reset} $1"; }
fail()  { echo "${red}✘${reset} $1"; }
head()  { echo "${reset}⎯ $1 ⎯${reset}"; }

# ─── Preflight: Homebrew must exist (installed by devbase-setup.sh) ─

if ! command -v brew &>/dev/null; then
  fail "Homebrew not found. Run devbase-setup.sh first."
  exit 1
fi

# ─── Install functions ───────────────────────────────────────

install_claude_code() {
  if command -v claude &>/dev/null; then
    skip "Already installed: claude $(claude --version 2>/dev/null || echo '?')"
    return 1
  fi
  info "Installing Claude Code via native installer…"
  if curl -fsSL https://claude.ai/install.sh | bash; then
    ok "Claude Code installed"
    return 0
  else
    fail "Claude Code install failed"
    return 2
  fi
}

install_claude_desktop() {
  if [[ -d "/Applications/Claude.app" ]] || brew list --cask claude &>/dev/null 2>&1; then
    skip "Already installed: Claude.app"
    return 1
  fi
  info "Installing Claude Desktop via Homebrew…"
  if brew install --cask claude; then
    ok "Claude Desktop installed"
    return 0
  else
    fail "Claude Desktop install failed"
    return 2
  fi
}

install_codexbar() {
  if [[ -d "/Applications/CodexBar.app" ]] || brew list --cask codexbar &>/dev/null 2>&1; then
    skip "Already installed: CodexBar.app"
    return 1
  fi
  info "Tapping steipete/tap…"
  brew tap steipete/tap 2>/dev/null || true
  info "Installing CodexBar via Homebrew…"
  if brew install --cask steipete/tap/codexbar; then
    ok "CodexBar installed"
    return 0
  else
    fail "CodexBar install failed"
    return 2
  fi
}

install_chrome_ext() {
  info "Opening Chrome Web Store for Claude in Chrome…"
  open 'https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn' 2>/dev/null || true
  ok "Chrome Web Store opened — install manually"
  return 0
}

# ─── Main ───────────────────────────────────────────────────

head "Claude ecosystem bootstrap"
echo

step_keys=(claude_code claude_desktop codexbar chrome_ext)
step_labels=("Claude Code (native installer)" "Claude Desktop" "CodexBar" "Claude in Chrome extension")
step_results=()

for i in "${!step_keys[@]}"; do
  key="${step_keys[$i]}"
  label="${step_labels[$i]}"
  head "$label"

  rc=0
  "install_$key" || rc=$?

  case $rc in
    0) step_results+=("ok") ;;
    1) step_results+=("skip") ;;
    *) step_results+=("fail") ;;
  esac

  echo
done

# ─── Summary ────────────────────────────────────────────────

head "Summary"
echo

for i in "${!step_keys[@]}"; do
  label="${step_labels[$i]}"
  status="${step_results[$i]}"
  case $status in
    ok)   ok   "$label" ;;
    skip) skip "$label (already installed)" ;;
    fail) fail "$label" ;;
  esac
done

# ─── Manual steps ───────────────────────────────────────────

echo
head "Manual steps needed"
echo

info "Run: claude login                       → authenticate Claude Code"
info "Open Claude.app                         → sign in with your account"
info "Open CodexBar                           → enable Claude provider in Settings → Providers"
info "Chrome Web Store                        → click \"Add to Chrome\" if not done"
info "Claude Desktop → Settings → Connectors  → enable Claude in Chrome connector"
