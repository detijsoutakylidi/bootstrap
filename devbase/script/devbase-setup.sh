#!/usr/bin/env bash

#
# Base bootstrap for a fresh Mac.
#
# Installs: Xcode CLT, Rosetta 2, Homebrew, Git, jq, ripgrep, gh.
# Configures: global gitignore.
# Run this FIRST, before the Claude or VS Code scripts.
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

# ─── Xcode Command Line Tools ──────────────────────────────

head "Xcode Command Line Tools"

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

echo

# ─── Rosetta 2 (Apple Silicon only) ────────────────────────

head "Rosetta 2"

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

echo

# ─── Homebrew ───────────────────────────────────────────────

head "Homebrew"

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

echo

# ─── Git ─────────────────────────────────────────────────────

head "Git"

if command -v git &>/dev/null; then
  skip "Already installed: $(git --version)"
else
  info "Installing Git via Homebrew…"
  brew install git
  ok "Git installed"
fi

echo

# ─── Git global config ──────────────────────────────────────

head "Git global config"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GITIGNORE_SRC="$SCRIPT_DIR/gitignore_global"
GITIGNORE_DST="$HOME/.gitignore_global"

if [[ -f "$GITIGNORE_SRC" ]]; then
  cp "$GITIGNORE_SRC" "$GITIGNORE_DST"
  git config --global core.excludesFile "$GITIGNORE_DST"
  ok "Global gitignore installed → $GITIGNORE_DST"
else
  fail "gitignore_global not found in script directory"
fi

echo

# ─── jq ──────────────────────────────────────────────────────

head "jq"

if command -v jq &>/dev/null; then
  skip "Already installed: $(jq --version)"
else
  info "Installing jq via Homebrew…"
  brew install jq
  ok "jq installed"
fi

echo

# ─── ripgrep ─────────────────────────────────────────────────

head "ripgrep"

if command -v rg &>/dev/null; then
  skip "Already installed: $(rg --version | head -1)"
else
  info "Installing ripgrep via Homebrew…"
  brew install ripgrep
  ok "ripgrep installed"
fi

echo

# ─── GitHub CLI ──────────────────────────────────────────────

head "GitHub CLI"

if command -v gh &>/dev/null; then
  skip "Already installed: $(gh --version | head -1)"
else
  info "Installing GitHub CLI via Homebrew…"
  brew install gh
  ok "GitHub CLI installed"
fi

echo

# ─── Summary ────────────────────────────────────────────────

head "Done"
echo
info "Your Mac is now ready for:"
info "  → bash claude/script/claude-setup.sh   (Claude ecosystem)"
info "  → bash vscode/script/vscode-setup.sh   (VS Code)"
info "  → bash terminal/script/terminal-setup.sh (Terminal.app)"
echo
info "Manual step:"
info "  Run: gh auth login                     → authenticate GitHub CLI"
