# Adding New Tools to Bootstrap

## Steps

### 1. Choose install vs configure

- **Install phase** — needs admin (brew install, cask, system config like /etc/hosts)
- **Configure phase** — user-level (dotfiles, editor settings, extensions)

Some tools need both (e.g., VS Code: install the app, then configure extensions).

### 2. Add the function

Follow the existing pattern:

```bash
install_toolname() {
  section "Tool Name"

  if [[ already installed check ]]; then
    skip "Already installed: Tool Name"
  else
    info "Installing Tool Name…"
    brew install toolname
    ok "Tool Name installed"
  fi
}
```

For configure functions, use the merge helpers when deploying config files:
- `merge_lines_config` for line-based files
- `merge_json_config` for JSON/JSONC with `"object"` or `"array:field"` type

### 3. Add config files

Place in `bootstrap/script/config/<toolname>/`. These are fetched at runtime via `fetch_config "toolname/filename"` — works for both local checkout and curl runs.

Use placeholders (`__HOME__`, `__PROJECTS_DIR__`) for machine-specific paths in config files.

### 4. Add the section flag

In argument parsing:
```bash
SEC_TOOLNAME=false                    # init
--toolname) SEC_TOOLNAME=true; SECTION_SPECIFIED=true ;;  # parse
do_toolname() { $SEC_TOOLNAME; }      # helper
```

Decide: included in default set (add to line 443) or opt-in only?

If opt-in, add an `--extended` prompt:
```bash
if $EXTENDED && ! $SEC_TOOLNAME && do_install; then
  read -rp "▸ Install Tool Name? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] && SEC_TOOLNAME=true
fi
```

### 5. Wire into main

Add to the install and/or configure dispatch at the bottom:
```bash
if do_toolname; then install_toolname; fi    # install phase
if do_toolname; then configure_toolname; fi  # configure phase
```

### 6. Update sections display

Add to the SECTIONS string builder:
```bash
$SEC_TOOLNAME && SECTIONS="${SECTIONS}toolname "
```

### 7. Update docs

- `CLAUDE.md` — structure tree, run section, flags
- `CHANGELOG.md` — entry for today
- `create.md` / `update.md` — if the tool has config files that need syncing
- Usage string in the `*)` error case
