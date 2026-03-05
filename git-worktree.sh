#!/bin/bash

set -e

USAGE="Usage: gwt <branch-name>
       gwt -c <branch-name> -- <command> [args...]
       gwt -d <branch-name>
       gwt -l
       gwt -h | --help

Options:
  <branch-name>           Create a worktree and print its path
  -c <branch> -- <cmd>    Create a worktree and run a command in it
  -d <branch>             Delete a worktree
  -D <branch>             Delete worktree and local branch
  -b                      Print the main worktree path
  -l                      List all worktrees
  -h, --help              Show this help message"

if [ -z "$1" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "$USAGE"
  exit 0
fi

if ! command -v git &>/dev/null; then
  echo "Error: git is not installed. Install it from https://git-scm.com"
  exit 1
fi

if ! git rev-parse --git-dir &>/dev/null; then
  echo "Error: not inside a git repository. Run 'git init' or cd into a repo."
  exit 1
fi

if [ "$1" = "-l" ]; then
  # Header
  printf "%-40s %-15s %-8s %-8s %-16s %s\n" "PATH" "BRANCH" "STATUS" "SYNC" "LAST COMMIT" "STASHES"

  # Parse porcelain output for paths and branches
  wt_path=""
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_path="${line#worktree }"
    elif [[ "$line" == "branch "* ]]; then
      branch="${line#branch refs/heads/}"
      branch="[$branch]"
    elif [[ "$line" == "HEAD "* ]]; then
      : # skip HEAD lines
    elif [[ "$line" == "bare" ]]; then
      branch="(bare)"
    elif [[ "$line" == "detached" ]]; then
      branch="(detached)"
    elif [[ -z "$line" && -n "$wt_path" ]]; then
      # Blank line = end of entry, gather info

      # Dirty/clean status
      if [ -d "$wt_path" ]; then
        porcelain=$(git -C "$wt_path" status --porcelain 2>/dev/null)
        if [ -n "$porcelain" ]; then
          status="dirty"
        else
          status="clean"
        fi
      else
        status="N/A"
      fi

      # Ahead/behind remote
      sync=$(git -C "$wt_path" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || true)
      if [ -n "$sync" ]; then
        behind=$(echo "$sync" | awk '{print $1}')
        ahead=$(echo "$sync" | awk '{print $2}')
        sync_str="↑${ahead} ↓${behind}"
      else
        sync_str="-"
      fi

      # Last commit date
      last_commit=$(git -C "$wt_path" log -1 --format='%cr' 2>/dev/null || echo "N/A")

      # Stash count
      stash_count=$(git -C "$wt_path" stash list 2>/dev/null | wc -l | tr -d ' ')

      # Shorten path: ~/.../<repo-dir>
      display_path="${wt_path/#$HOME/\~}"
      max_path=40
      if [ ${#display_path} -gt $max_path ]; then
        repo_dir="${display_path##*/}"
        display_path="~/.../$repo_dir"
      fi

      printf "%-40s %-15s %-8s %-8s %-16s %s\n" "$display_path" "$branch" "$status" "$sync_str" "$last_commit" "$stash_count"

      wt_path=""
      branch=""
    fi
  done < <(git worktree list --porcelain; echo "")
  exit 0
fi

if [ "$1" = "-b" ]; then
  if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
    cd "$(git rev-parse --git-dir)" && pwd
  else
    git worktree list --porcelain | head -1 | sed 's/worktree //'
  fi
  exit 0
fi

if [ "$1" = "-d" ] || [ "$1" = "-D" ]; then
  FLAG="$1"
  shift
  if [ -z "$1" ]; then
    echo "$USAGE"
    exit 1
  fi
  BRANCH="$1"
  if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
    REPO_DIR="$(cd "$(git rev-parse --git-dir)" && pwd)"
  else
    REPO_DIR="$(git rev-parse --show-toplevel)"
  fi
  REPO_NAME="$(basename "$REPO_DIR")"
  PARENT_DIR="$(dirname "$REPO_DIR")"
  WORKTREE_DIR="$PARENT_DIR/$REPO_NAME-$BRANCH"

  git worktree remove "$WORKTREE_DIR"
  echo "Removed worktree at $WORKTREE_DIR"

  if [ "$FLAG" = "-D" ]; then
    DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
    if [ -z "$DEFAULT_BRANCH" ]; then
      DEFAULT_BRANCH=$(git config init.defaultBranch 2>/dev/null || echo "main")
    fi
    if [ "$BRANCH" = "$DEFAULT_BRANCH" ]; then
      echo "Cannot delete the default branch '$DEFAULT_BRANCH'"
    else
      read -rp "Delete local branch '$BRANCH'? [y/N] " confirm
      if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        git branch -d "$BRANCH"
        echo "Deleted branch $BRANCH"
      else
        echo "Kept branch $BRANCH"
      fi
    fi
  fi
  exit 0
fi

CMD=()
if [ "$1" = "-c" ]; then
  shift
  if [ -z "$1" ]; then
    echo "$USAGE"
    exit 1
  fi
  BRANCH="$1"
  shift
  if [ "$1" = "--" ]; then
    shift
  fi
  if [ $# -eq 0 ]; then
    echo "Error: no command specified after --"
    exit 1
  fi
  CMD=("$@")
else
  BRANCH="$1"
fi
if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
  REPO_DIR="$(cd "$(git rev-parse --git-dir)" && pwd)"
else
  REPO_DIR="$(git rev-parse --show-toplevel)"
fi
REPO_NAME="$(basename "$REPO_DIR")"
PARENT_DIR="$(dirname "$REPO_DIR")"
WORKTREE_DIR="$PARENT_DIR/$REPO_NAME-$BRANCH"

EXISTING=$(git worktree list --porcelain | awk -v branch="$BRANCH" '
  /^worktree / { path = substr($0, 10) }
  /^branch / { if ($0 == "branch refs/heads/" branch) print path }
')

if [ -n "$EXISTING" ]; then
  WORKTREE_DIR="$EXISTING"
elif [ ! -d "$WORKTREE_DIR" ]; then
  git worktree add "$WORKTREE_DIR" -b "$BRANCH" >&2 2>/dev/null \
    || git worktree add "$WORKTREE_DIR" "$BRANCH" >&2
  echo "Created worktree at $WORKTREE_DIR" >&2
fi

if [ ${#CMD[@]} -gt 0 ]; then
  cd "$WORKTREE_DIR" && exec "${CMD[@]}"
else
  echo "$WORKTREE_DIR"
fi
