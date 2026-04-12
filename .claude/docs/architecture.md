# Architecture

## Two-Phase Design

Bootstrap splits work into two phases based on privilege requirements:

- **Install** (system-level, admin required) — Homebrew, casks, CLI tools, `/etc/hosts`
- **Configure** (user-level, no admin) — dotfiles, editor config, extensions, file associations

Both phases auto-detect admin status via `dseditgroup` (macOS) / `WindowsPrincipal` (Windows). Non-admin users get configure-only mode automatically.

## Section Flags

Each section can run independently via flags:

| Flag | Install | Configure | Default |
|------|---------|-----------|---------|
| `--base` | Xcode CLT, Homebrew, Git, jq, rg, gh | gitignore | yes |
| `--vscode` | VS Code app, duti | extensions, settings, keybindings | yes |
| `--vscode-assoc` | — | file associations only | no |
| `--claude` | Claude Code, Claude Desktop, CodexBar | CLAUDE.md, djtl rules, new-project, session retention | yes |
| `--terminal` | — | Terminal.app profile, shell prompt | yes |
| `--herd` | Herd app, /etc/hosts entries | — | no (opt-in) |

`--extended` adds interactive prompts for optional items (VS Code extensions, Herd).

## Config File Flow

```
config/vscode/settings.json          →  ~/Library/.../Code/User/settings.json
       (with __HOME__, __PROJECTS_DIR__     (rendered via sed at runtime)
        placeholders)

config/git/gitignore_global           →  ~/.gitignore_global
config/claude/CLAUDE-djtl.md          →  ~/.claude/CLAUDE-djtl.md (always overwrite)
config/codexbar/config.json           →  ~/.codexbar/config.json
config/herd/private-hosts             →  /etc/hosts (append missing entries)
config/terminal/Pro.terminal          →  Terminal.app defaults database
```

All config files are fetched via `fetch_config()` which tries local checkout first, then downloads from raw GitHub. This enables both local runs and cloud install via `bash <(curl ...)`.

## Merge System

Three strategies based on file type:

| Strategy | Used For | Method |
|----------|----------|--------|
| `merge_lines_config` | gitignore | Line-by-line comparison, grouped into common/local-only/new |
| `merge_json_config "object"` | settings.json, codexbar config | Top-level key comparison via embedded Python |
| `merge_json_config "array:fields"` | keybindings, codexbar providers | Array entries matched by identity fields |

All offer Skip / Overwrite / Merge with bulk actions per group.

The Python merge helper handles JSONC (strips `//` comments and trailing commas) and preserves setup key ordering in output.

## Version Stamp

Each script embeds a `BOOTSTRAP_BUILD` timestamp (e.g. `260312-2246`). When run from a local checkout, the git hash is appended (`260312-2246 a1b2c3d`). For curl runs, only the timestamp shows — enough to verify you're running the right version through CDN caching.
