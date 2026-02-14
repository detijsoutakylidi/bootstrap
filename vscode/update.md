# VS Code Setup — Update Playbook

Instructions for Claude Code to follow when updating the setup script from the current live VS Code configuration.

## When to Use

Run this workflow when asked to sync/update the VS Code setup script with the current machine's config.

## Step 0. Offer Config Revision

Before syncing, ask the user if they want to revise their VS Code config. If yes, perform these steps on the **live** config files at `~/Library/Application Support/Code/User/`:

### 0a. Clean up orphaned extension references

1. Run `code --list-extensions` to get the list of currently installed extensions
2. Scan `settings.json` for settings namespaced to extensions that are no longer installed (e.g. `better-comments.*`, `supermaven.*`, `simple-project-switcher.*`)
3. Scan `keybindings.json` for bindings that reference commands from uninstalled extensions
4. Present findings to the user and remove confirmed orphans

### 0b. Reorganize settings into logical groups

1. Check if `settings.json` has settings scattered outside their logical group (e.g. `editor.minimap.*` far from other editor settings, `workbench.editor.*` mixed into unrelated sections)
2. If disorganized, reorganize into groups following the established pattern:
   - Each group has a comment header: `// group name — description of what belongs here`
   - Groups: window, workbench, explorer & search, problems, editor (appearance, minimap, brackets, suggestions), silence the noise, diff editor, scm & git, files, terminal, security & telemetry, PHP, then extension-specific groups
3. Show the user the proposed reorganization before applying

### 0c. Reorganize keybindings into logical groups

1. Check if `keybindings.json` has bindings scattered outside their logical group
2. If disorganized, reorganize following the established pattern:
   - Each group has a comment header: `// group name — description of what belongs here`
   - Each binding has a comment above it explaining what the shortcut does
   - Groups: panels, explorer, code navigation, editing, terminal, then extension-specific groups
3. Show the user the proposed reorganization before applying

**Important:** Back up both files before making revision changes (copy to `.bak`).

## Steps

### 1. Compare Extensions

Run `code --list-extensions` and compare against the two lists in `vscode/script/vscode-setup.sh`:
- **Essential** extensions (installed without prompt)
- **Optional** extensions (user is asked y/n)

Present a table showing:
- Extensions in the script but NOT currently installed (candidates for removal)
- Extensions currently installed but NOT in the script (candidates for addition)

Ask the user for each diff:
- Add to essential, add to optional, or skip?
- Remove from script or keep?

### 2. Compare Settings

Read the live `~/Library/Application Support/Code/User/settings.json` and diff against `vscode/script/settings.json`.

Before diffing, remember that the stored file uses placeholders:
- `__HOME__` → replace with `/Users/<current-user>` for comparison
- `__PROJECTS_DIR__` → replace with the current `projectManager.git.baseFolders` value for comparison

Show the user meaningful diffs (skip whitespace-only changes). Update the stored file with approved changes, re-applying the placeholders afterward.

### 3. Compare Keybindings

Read the live `~/Library/Application Support/Code/User/keybindings.json` and diff against `vscode/script/keybindings.json`.

Show diffs, update with approved changes.

### 4. Finalize

After all updates:
- Verify `settings.json` still contains `__HOME__` and `__PROJECTS_DIR__` placeholders (not hardcoded paths)
- Ask whether to commit the changes
