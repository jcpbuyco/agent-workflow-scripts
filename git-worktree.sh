#!/bin/bash

gwt() {
  local usage="Usage: gwt <branch-name>\n       gwt -d <branch-name>"

  if [ -z "$1" ]; then
    echo -e "$usage"
    return 1
  fi

  local DELETE=false
  if [ "$1" = "-d" ]; then
    DELETE=true
    shift
    if [ -z "$1" ]; then
      echo -e "$usage"
      return 1
    fi
  fi

  local BRANCH="$1"
  local REPO_DIR="$(git rev-parse --show-toplevel)"
  local REPO_NAME="$(basename "$REPO_DIR")"
  local PARENT_DIR="$(dirname "$REPO_DIR")"
  local WORKTREE_DIR="$PARENT_DIR/$REPO_NAME-$BRANCH"

  if [ "$DELETE" = true ]; then
    git worktree remove "$WORKTREE_DIR"
    echo "Removed worktree at $WORKTREE_DIR"
    return 0
  fi

  if [ -d "$WORKTREE_DIR" ]; then
    echo "Directory already exists, navigating to it"
    cd "$WORKTREE_DIR"
    return 0
  fi

  git worktree add "$WORKTREE_DIR" -b "$BRANCH" 2>/dev/null \
    || git worktree add "$WORKTREE_DIR" "$BRANCH"

  echo "Created worktree at $WORKTREE_DIR"
  cd "$WORKTREE_DIR"
}
