#!/usr/bin/env bash

input=$(cat)

# Catppuccin Macchiato colors
MAUVE=$'\033[38;2;198;160;246m'
TEAL=$'\033[38;2;139;213;202m'
SAPPHIRE=$'\033[38;2;125;196;228m'
PEACH=$'\033[38;2;245;169;127m'
RESET=$'\033[0m'

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$cwd")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# Build progress bar
bar=""
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  filled=$(( used_int * 10 / 100 ))
  empty=$(( 10 - filled ))
  for ((i=0; i<filled; i++)); do bar="${bar}▮"; done
  for ((i=0; i<empty; i++)); do bar="${bar}▯"; done
  ctx_part="${bar} ${used_int}%"
else
  ctx_part="▯▯▯▯▯▯▯▯▯▯ --%"
fi

location=""
if [ -n "$repo" ]; then
  location="${SAPPHIRE}"$'\uf07b'"${TEAL} $repo"
  if [ -n "$branch" ]; then
    location="$location  ${MAUVE}"$'\ue725'"${TEAL} $branch"
  fi
fi

echo "${TEAL}${location}${RESET}"
echo "${MAUVE}${model}${RESET}  ${PEACH}${ctx_part}${RESET}"
