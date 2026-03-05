#!/usr/bin/env bash

input=$(cat)

# Catppuccin Macchiato colors
MAUVE=$'\033[38;2;198;160;246m'
TEAL=$'\033[38;2;139;213;202m'
SAPPHIRE=$'\033[38;2;125;196;228m'
BLUE=$'\033[38;2;138;173;244m'
PEACH=$'\033[38;2;245;169;127m'
GREEN=$'\033[38;2;166;218;149m'
RED=$'\033[38;2;237;135;150m'
RESET=$'\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
added=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
removed=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms // 0')
duration_s=$(( duration_ms / 1000 ))
duration_m=$(( duration_s / 60 ))
duration_h=$(( duration_m / 60 ))
if [ $duration_h -gt 0 ]; then
  duration="${duration_h}h $((duration_m % 60))m"
elif [ $duration_m -gt 0 ]; then
  duration="${duration_m}m $((duration_s % 60))s"
else
  duration="${duration_s}s"
fi
cwd=$(echo "$input" | jq -r '.cwd // empty')
main_worktree=$(git -C "$cwd" worktree list --porcelain 2>/dev/null | head -1 | sed 's/worktree //')
repo=$(basename "${main_worktree:-$cwd}")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Build progress bar
bar=""
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  filled=$(( used_int * 6 / 100 ))
  empty=$(( 6 - filled ))
  for ((i=0; i<filled; i++)); do bar="${bar}|"; done
  for ((i=0; i<empty; i++)); do bar="${bar}·"; done
  ctx_part="${bar} ${used_int}%"
else
  ctx_part="······ --%"
fi

location=""
if [ -n "$repo" ]; then
  location="${SAPPHIRE}"$'\xef\x81\xbb'"${TEAL} $repo"
  if [ -n "$branch" ]; then
    location="$location  ${MAUVE}"$'\xee\x9c\xa5'"${TEAL} $branch  ${GREEN}+${added}${RESET} ${RED}-${removed}${RESET}"
  fi
fi

echo "${TEAL}${location}${RESET}"
echo "${BLUE}${model}${RESET}  ${PEACH}${ctx_part}${RESET}  ${duration}"
