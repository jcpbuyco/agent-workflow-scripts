# Agent Workflow Scripts

Shell utilities for streamlining development workflows.

## Scripts

### `gwt` - Git Worktree Helper

A shell function that simplifies creating, navigating, and managing git worktrees. Worktrees are created as sibling directories named `<repo>-<branch>`.

#### Setup

Source the script in your `.zshrc` or `.bashrc`:

```bash
source /path/to/git-worktree.sh
```

#### Usage

```
gwt <branch-name>       # Create a worktree and cd into it
gwt -d <branch-name>    # Delete a worktree
gwt -l                  # List all worktrees
gwt -h | --help         # Show help
```
