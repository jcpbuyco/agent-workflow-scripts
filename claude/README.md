# Claude Code Customizations

Custom scripts for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

## Statusline

`statusline-command.sh` — Custom status line using the Catppuccin Macchiato theme.

Displays:
- Directory and git branch (with Nerd Font icons)
- Model name
- Context window usage progress bar

### Setup

Symlink the script and configure Claude Code:

```bash
ln -s "$(pwd)/statusline-command.sh" ~/.claude/statusline-command.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Requirements

- [Nerd Font](https://www.nerdfonts.com/) set as your terminal font
- `jq` installed
- `git` (for branch display)
