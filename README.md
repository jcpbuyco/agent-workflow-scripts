# Agent Workflow Scripts

Shell utilities for streamlining development workflows.

## Installation

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd)/git-worktree.sh" ~/.local/bin/gwt
```

Make sure `~/.local/bin` is in your `PATH`. Add this to your `.zshrc` or `.bashrc` if it isn't:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

To quickly navigate between worktrees, add this to your `.zshrc` or `.bashrc`:

```bash
gwtcd() { cd "$(gwt "$@")"; }
```

## Scripts

### `gwt` - Git Worktree Helper

Simplifies creating, navigating, and managing git worktrees. Worktrees are created as sibling directories named `<repo>-<branch>`.

#### Usage

```
gwt <branch-name>                  # Create a worktree and print its path
gwt -c <branch> -- <cmd> [args]    # Create a worktree and run a command in it
gwt -d <branch-name>               # Delete a worktree
gwt -l                             # List all worktrees
gwt -h | --help                    # Show help
```

#### Example: Using with Claude Code

```bash
gwt -c my-feature -- claude
```

This creates a worktree on the `my-feature` branch and starts a Claude Code session in it, isolating your work from the main branch.
