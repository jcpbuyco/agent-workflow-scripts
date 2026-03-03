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

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "Error: not inside a git repository. Run 'git init' or cd into a repo."
  exit 1
fi

if [ "$1" = "-l" ]; then
  git worktree list
  exit 0
fi

if [ "$1" = "-b" ]; then
  git worktree list --porcelain | head -1 | sed 's/worktree //'
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
  REPO_DIR="$(git rev-parse --show-toplevel)"
  REPO_NAME="$(basename "$REPO_DIR")"
  PARENT_DIR="$(dirname "$REPO_DIR")"
  WORKTREE_DIR="$PARENT_DIR/$REPO_NAME-$BRANCH"

  git worktree remove "$WORKTREE_DIR"
  echo "Removed worktree at $WORKTREE_DIR"

  if [ "$FLAG" = "-D" ]; then
    read -rp "Delete local branch '$BRANCH'? [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
      git branch -d "$BRANCH"
      echo "Deleted branch $BRANCH"
    else
      echo "Kept branch $BRANCH"
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
REPO_DIR="$(git rev-parse --show-toplevel)"
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
  git worktree add "$WORKTREE_DIR" -b "$BRANCH" 2>/dev/null \
    || git worktree add "$WORKTREE_DIR" "$BRANCH"
  echo "Created worktree at $WORKTREE_DIR" >&2
fi

if [ ${#CMD[@]} -gt 0 ]; then
  cd "$WORKTREE_DIR" && exec "${CMD[@]}"
else
  echo "$WORKTREE_DIR"
fi
