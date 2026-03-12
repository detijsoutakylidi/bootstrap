#!/bin/bash

# Creates a new project with git repo and CLAUDE.md template in current directory.
# Install: ln -s projects/scripts/new-project.sh $CODE/new-project.sh
# Run from $CODE: bash new-project.sh <name> [description]

CODE_DIR="$(pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && cd "$(dirname "$(readlink "$(basename "$0")")")" && pwd)"

if [ -z "$1" ]; then
  echo "Creates a new project with git repo and CLAUDE.md template in current folder."
  echo ""
  echo "Usage: bash new-project.sh <project-name> [description]"
  exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$CODE_DIR/$PROJECT_NAME"
DESCRIPTION="${2:-}"

if [ -d "$PROJECT_DIR" ]; then
  echo "Error: $PROJECT_DIR already exists"
  exit 1
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

git init -q

cat > .gitignore << EOF

EOF

sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{DESCRIPTION}}/${DESCRIPTION:-TODO: Add project description}/g" \
    "$SCRIPT_DIR/project-en.md" > CLAUDE.md

sed -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    "$SCRIPT_DIR/personal-en.md" > "CLAUDE-personal-project..md"

GLOBAL_DJTL="$HOME/.claude/CLAUDE-djtl.md"
GLOBAL_PERSONAL="$HOME/.claude/CLAUDE.md"

ln -s "$GLOBAL_DJTL" "CLAUDE-djtl-global..md"
ln -s "$GLOBAL_PERSONAL" "CLAUDE-personal-global..md"

git add -A
git commit -q -m "Initial project setup"

echo "Created $PROJECT_DIR"
echo "  - git initialized"
echo "  - .gitignore created"
echo "  - CLAUDE.md created"
echo "  - CLAUDE-djtl-global..md symlinked -> $GLOBAL_DJTL"
echo "  - CLAUDE-personal-global..md symlinked -> $GLOBAL_PERSONAL"
echo "  - CLAUDE-personal-project..md created (gitignored)"

open -a "Visual Studio Code" .
