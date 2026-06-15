#!/bin/bash

set -e

USAGE="Usage: gwt <branch-name>
       gwt -c <branch-name> -- <command> [args...]
       gwt -d <branch-name>
       gwt -l
       gwt -p [--dry-run]
       gwt --fix-remote-tracking
       gwt -h | --help

Options:
  <branch-name>           Create a worktree and print its path
  -c <branch> -- <cmd>    Create a worktree and run a command in it
  -d <branch>             Delete a worktree
  -D <branch>             Delete worktree and local branch
  -b                      Print the main worktree path
  -p [--dry-run]          Prune worktrees whose branch is gone from remote
  --fix-remote-tracking   Add fetch refspec and fetch remote tracking refs
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

# Detect bare repo (directly or from inside a worktree of one)
is_bare_repo() {
  if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
    return 0
  fi
  git -C "$(git rev-parse --git-common-dir)" rev-parse --is-bare-repository 2>/dev/null | grep -q true
}

get_repo_dir() {
  if is_bare_repo; then
    cd "$(git rev-parse --git-common-dir)" && pwd
  else
    git rev-parse --show-toplevel
  fi
}

if [ "$1" = "-p" ]; then
  dry_run=false
  if [ "$2" = "--dry-run" ]; then
    dry_run=true
  fi
  REPO_DIR="$(get_repo_dir)"
  # Ensure fetch refspec exists for bare repos
  existing_fetch=$(git -C "$REPO_DIR" config --get remote.origin.fetch 2>/dev/null || true)
  if [ -z "$existing_fetch" ]; then
    echo "Error: no fetch refspec configured. Run 'gwt --fix-remote-tracking' first."
    exit 1
  fi
  # Fetch and prune remote refs
  git -C "$REPO_DIR" fetch --prune origin
  # Get list of remote branches
  remote_branches=$(git -C "$REPO_DIR" for-each-ref --format='%(refname:short)' refs/remotes/origin/ 2>/dev/null | sed 's|^origin/||')
  if [ -z "$remote_branches" ]; then
    echo "Error: no remote branches found. Check your remote configuration."
    exit 1
  fi
  pruned=0
  while IFS= read -r wt_line; do
    [[ "$wt_line" == worktree\ * ]] || continue
    wt_path="${wt_line#worktree }"
    # Read the next lines to find the branch
    IFS= read -r next_line
    # Skip HEAD line
    while [[ "$next_line" == "HEAD "* ]]; do
      IFS= read -r next_line
    done
    [[ "$next_line" == "branch "* ]] || continue
    wt_branch="${next_line#branch refs/heads/}"
    # Skip the main/default branch
    default_branch=$(git -C "$REPO_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
    [ "$wt_branch" = "$default_branch" ] && continue
    # Only prune branches that were tracking a remote (i.e. were pushed before)
    branch_remote=$(git -C "$REPO_DIR" config "branch.${wt_branch}.remote" 2>/dev/null || true)
    [ -z "$branch_remote" ] && continue
    # Check if branch is gone from remote
    if ! echo "$remote_branches" | grep -qx "$wt_branch"; then
      if $dry_run; then
        echo "[dry-run] Would prune: $wt_branch ($wt_path)"
      else
        # Check for uncommitted changes
        if [ -d "$wt_path" ]; then
          porcelain=$(git -C "$wt_path" status --porcelain 2>/dev/null || true)
          if [ -n "$porcelain" ]; then
            echo "Skipping $wt_branch (has uncommitted changes)"
            continue
          fi
        fi
        git worktree remove "$wt_path" 2>/dev/null && git branch -d "$wt_branch" 2>/dev/null || true
        echo "Pruned: $wt_branch ($wt_path)"
      fi
      pruned=$((pruned + 1))
    fi
  done < <(git -C "$REPO_DIR" worktree list --porcelain)
  if [ $pruned -eq 0 ]; then
    echo "Nothing to prune. All worktree branches exist on remote."
  fi
  exit 0
fi

if [ "$1" = "--fix-remote-tracking" ]; then
  REPO_DIR="$(get_repo_dir)"
  existing=$(git -C "$REPO_DIR" config --get remote.origin.fetch 2>/dev/null || true)
  if [ -n "$existing" ]; then
    echo "remote.origin.fetch already set: $existing"
  else
    git -C "$REPO_DIR" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    echo "Added fetch refspec to remote.origin"
  fi
  echo "Fetching from origin..."
  git -C "$REPO_DIR" fetch origin
  echo "Done. Remote tracking refs are now available."
  exit 0
fi

if [ "$1" = "-l" ]; then
  # Parse porcelain output for paths and branches
  wt_path=""
  is_bare=false
  wt_count=0
  while IFS= read -r line; do
    if [[ "$line" == worktree\ * ]]; then
      wt_path="${line#worktree }"
    elif [[ "$line" == "branch "* ]]; then
      raw_branch="${line#branch refs/heads/}"
      branch="$raw_branch"
      max_branch=30
      if [ ${#branch} -gt $max_branch ]; then
        branch="${branch:0:$((max_branch - 1))}…"
      fi
      # Pad branch to fixed display width (printf miscounts multi-byte …)
      branch_pad=$((max_branch - ${#branch}))
      branch="${branch}$(printf '%*s' "$branch_pad" '')"
    elif [[ "$line" == "HEAD "* ]]; then
      : # skip HEAD lines
    elif [[ "$line" == "bare" ]]; then
      branch="(bare)"
      is_bare=true
    elif [[ "$line" == "detached" ]]; then
      branch="(detached)"
    elif [[ -z "$line" && -n "$wt_path" ]]; then
      # Blank line = end of entry, gather info

      if $is_bare; then
        wt_path=""
        branch=""
        is_bare=false
        continue
      fi
      # Dirty/clean status
      if [ -d "$wt_path" ]; then
        porcelain=$(git -C "$wt_path" status --porcelain 2>/dev/null || true)
        if [ -n "$porcelain" ]; then
          status="dirty"
        else
          status="clean"
        fi
      else
        status="N/A"
      fi

      # Ahead/behind remote (try @{upstream}, fall back to remote merge ref)
      sync=$(git -C "$wt_path" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null || true)
      if [ -z "$sync" ] && [ -n "$raw_branch" ]; then
        remote=$(git -C "$wt_path" config "branch.${raw_branch}.remote" 2>/dev/null || true)
        merge=$(git -C "$wt_path" config "branch.${raw_branch}.merge" 2>/dev/null || true)
        if [ -n "$remote" ] && [ -n "$merge" ]; then
          remote_ref="${remote}/${merge#refs/heads/}"
          sync=$(git -C "$wt_path" rev-list --left-right --count "${remote_ref}...HEAD" 2>/dev/null || true)
        fi
      fi
      if [ -n "$sync" ]; then
        behind=$(echo "$sync" | awk '{print $1}')
        ahead=$(echo "$sync" | awk '{print $2}')
        sync_str="↑${ahead} ↓${behind}"
      else
        sync_str="-"
      fi
      # Pad sync_str to 8 display chars (printf miscounts multi-byte arrows)
      sync_pad=$((10 - ${#sync_str}))
      sync_str="${sync_str}$(printf '%*s' "$sync_pad" '')"

      # Last commit date (compact: 3d, 2w, 5mo)
      last_commit=$(git -C "$wt_path" log -1 --format='%cr' 2>/dev/null || echo "N/A")
      last_commit=$(echo "$last_commit" | sed -E \
        -e 's/ seconds? ago/s/' \
        -e 's/ minutes? ago/m/' \
        -e 's/ hours? ago/h/' \
        -e 's/ days? ago/d/' \
        -e 's/ weeks? ago/w/' \
        -e 's/ months? ago/mo/' \
        -e 's/ years? ago/y/')


      # Shorten path: ~/.../<repo-dir>
      display_path="${wt_path/#$HOME/\~}"
      max_path=40
      if [ ${#display_path} -gt $max_path ]; then
        repo_dir="${display_path##*/}"
        display_path="~/.../$repo_dir"
      fi

      # Print header before first entry
      if [ $wt_count -eq 0 ]; then
        printf "%-40s %-8s %-30s %-16s %s\n" "PATH" "STATUS" "BRANCH" "LAST COMMIT" "SYNC"
      fi
      wt_count=$((wt_count + 1))

      printf "%-40s %-8s %s %-16s %s\n" "$display_path" "$status" "$branch" "$last_commit" "$sync_str"

      wt_path=""
      branch=""
      is_bare=false
    fi
  done < <(git worktree list --porcelain; echo "")
  if [ $wt_count -eq 0 ]; then
    echo "No worktrees available"
  fi
  exit 0
fi

if [ "$1" = "-b" ]; then
  if is_bare_repo; then
    get_repo_dir
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
  REPO_DIR="$(get_repo_dir)"
  if is_bare_repo; then
    WORKTREE_DIR="$REPO_DIR/$BRANCH"
  else
    REPO_NAME="$(basename "$REPO_DIR")"
    PARENT_DIR="$(dirname "$REPO_DIR")"
    WORKTREE_DIR="$PARENT_DIR/$REPO_NAME-$BRANCH"
  fi

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
REPO_DIR="$(get_repo_dir)"
if is_bare_repo; then
  WORKTREE_DIR="$REPO_DIR/$BRANCH"
else
  REPO_NAME="$(basename "$REPO_DIR")"
  PARENT_DIR="$(dirname "$REPO_DIR")"
  WORKTREE_DIR="$PARENT_DIR/$REPO_NAME-$BRANCH"
fi

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
