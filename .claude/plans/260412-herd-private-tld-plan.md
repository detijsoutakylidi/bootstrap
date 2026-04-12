# Add Herd + `.private` TLD support to bootstrap

**Date:** 2026-04-12
**Context:** The macmail project (and future local services) need a `.private` TLD pointing to localhost so they can be accessed as `http://{name}.private` without hardcoded ports. Herd provides the nginx reverse proxy on port 80 that makes this work.

## What needs to happen

### 1. New `--herd` section flag

Add `--herd` alongside existing `--base`, `--vscode`, `--claude`, `--terminal` flags. NOT included by default — this is opt-in because not every machine needs Herd.

### 2. `install_herd()` function

```
section "Laravel Herd"
```

- Check if Herd is installed (`/Applications/Herd.app` or `which herd`)
- If not: install via `brew install --cask herd`
- Verify Herd is running (it should auto-start after install)
- Verify nginx is listening on `127.0.0.1:80`

### 3. `configure_herd()` function

```
section ".private TLD"
```

Set up `/etc/hosts` entry for the `.private` TLD pattern:

- Check if `/etc/hosts` already contains a `.private` entry
- If not: append `127.0.0.1 macmail.private` (and any other known `.private` domains)
- Needs `sudo` — use the same pattern as other bootstrap sections that need elevated privileges

**Important:** Bootstrap only adds the `/etc/hosts` entries. It does NOT create nginx proxy configs — each project handles its own proxy registration via its own install command (e.g. `macmail install` creates the nginx config for `macmail.private → 127.0.0.1:7210`).

### 4. Config file approach

Create `config/herd/private-hosts` with the list of `.private` domains:

```
# Local service domains — resolved via /etc/hosts, proxied by Herd's nginx
# Each project registers its own nginx proxy config via its install command
macmail.private
```

The configure function reads this file and ensures all entries exist in `/etc/hosts` pointing to `127.0.0.1`. This way adding a new `.private` service is just one line in the config file + running bootstrap again.

### 5. Update script header and usage

Update the usage comment and `--help` output:
```
bash bootstrap.sh [--install | --configure] [--base] [--vscode] [--claude] [--terminal] [--herd]
```

### 6. Update CLAUDE.md structure section

Add `herd/` to the config directory listing and `--herd` to the run section.

## Key details

- Herd's nginx is a default server on `127.0.0.1:80` — it responds to ANY hostname, not just `.test`
- Herd's dnsmasq only resolves `.test` (`address=/.test/127.0.0.1`) — we don't touch it
- `/etc/hosts` bypasses DNS entirely — simpler and survives Herd updates
- Each project creates its own nginx proxy config at `~/Library/Application Support/Herd/config/valet/Nginx/{name}.private`
- The proxy config is a simple `server { listen 127.0.0.1:80; server_name {name}.private; location / { proxy_pass http://127.0.0.1:{port}; } }`

## Files to modify

- `bootstrap/script/bootstrap.sh` — add `--herd` flag, `install_herd()`
- `bootstrap/script/config/herd/private-hosts` — new config file with `.private` domains
- `CLAUDE.md` — update structure and run sections

## Verification

1. `bash bootstrap/script/bootstrap.sh --herd` — installs Herd, adds `/etc/hosts` entries
2. `grep macmail.private /etc/hosts` — confirms entry exists
3. `curl -s -H "Host: macmail.private" http://127.0.0.1:80/` — Herd's nginx responds (even without macmail running yet — will show Herd's default page)

## Execution notes (2026-04-12)

**Deviation from plan:** No `configure_herd()` — both Herd install and `/etc/hosts` modification require admin, so everything is in `install_herd()` (install phase only). This matches the bootstrap pattern where the configure phase is user-level (no sudo).

**Additional:** `--herd` is opt-in (not in default section set) AND offered interactively via `--extended` prompt before the banner. This follows the same dual-access pattern as other optional features.

**Completed:**
- [x] `--herd` flag in argument parsing (not in default set)
- [x] `do_herd()` helper
- [x] `install_herd()` — Herd app install via brew + /etc/hosts entries from config
- [x] `config/herd/private-hosts` — domain list
- [x] `--extended` interactive prompt for Herd
- [x] Wired into install phase dispatch
- [x] CLAUDE.md structure + run section updated
- [x] CHANGELOG.md updated
