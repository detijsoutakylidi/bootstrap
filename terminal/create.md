# Terminal Setup — Creation Playbook

How this setup script was created. See `vscode/create.md` for the general template.

## What was gathered

1. Terminal.app preferences via `defaults export com.apple.Terminal`
2. Default profile name (`Pro`) via `defaults read com.apple.Terminal "Default Window Settings"`
3. Extracted the Pro profile from `Window Settings` dict and exported as `.terminal` file
4. Shell prompt from `~/.zshrc` (`PROMPT='%1~ % '`)

## Decisions

- **Profile method**: Export as `.terminal` file and `open` it to import. Set as default via `defaults write`.
- **Prompt**: Only the `PROMPT=` line — other `.zshrc` content (PATH, exports) is out of scope.
- **Idempotent**: Checks if prompt is already set before modifying `.zshrc`. Profile import is safe to re-run.

## Profile customizations from stock Pro

- FontWidthSpacing: 0.996 (slightly tightened)
- FontAntialias: off
- useOptionAsMetaKey: true
- Bell: off
- BackgroundBlur: 0
- ShowWindowSettingsNameInTitle: off
