# Devbase Setup — Update Playbook

Instructions for Claude Code to follow when updating the devbase setup script.

## When to Use

Run this workflow when asked to sync/update the devbase setup script, typically when new CLI tools should be added to the base install.

## Steps

### 1. Review installed brew packages

1. Run `brew list` to see what's currently installed
2. Compare against the packages in `devbase/script/devbase-setup.sh`
3. Ask the user if any new packages should be added to the base install (vs. belonging in a specific tool's script)

### 2. Check install methods

1. Verify the Homebrew install URL is still current
2. Verify the Xcode CLT install method still works
3. Check if any installed tools have changed their recommended install method

### 3. Finalize

- Ask whether to commit the changes
