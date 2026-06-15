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

# Extract every field in a single jq pass (one value per line). Read line by
# line rather than with a tab IFS, so empty fields survive instead of collapsing.
{
  read -r model
  read -r version
  read -r ctx_used
  read -r ctx_total
  read -r added
  read -r removed
  read -r duration_ms
  read -r cwd
} < <(echo "$input" | jq -r '
  .model.display_name // "Unknown",
  (.version // ""),
  ((.context_window.current_usage
    | (.input_tokens + .output_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)) // 0),
  (.context_window.context_window_size // 0),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0),
  (.cost.total_api_duration_ms // 0),
  (.cwd // "")
')
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
main_worktree=$(git -C "$cwd" worktree list --porcelain 2>/dev/null | head -1 | sed 's/worktree //')
repo=$(basename "${main_worktree:-$cwd}")
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
tracking=$(git -C "$cwd" rev-list --left-right --count HEAD...@{upstream} 2>/dev/null || echo "")
ahead=$(echo "$tracking" | awk '{print $1}')
behind=$(echo "$tracking" | awk '{print $2}')

# Context window usage
used_k=$(( ctx_used / 1000 ))
total_k=$(( ctx_total / 1000 ))
ctx_part="${used_k}k/${total_k}k"

location=""
if [ -n "$repo" ]; then
  location="${SAPPHIRE}"$'\xef\x81\xbb'"${TEAL} $repo"
  if [ -n "$branch" ]; then
    sync=""
    if [ -n "$ahead" ] && [ "$ahead" -gt 0 ] 2>/dev/null; then sync="${GREEN}↑${ahead}${RESET}"; fi
    if [ -n "$behind" ] && [ "$behind" -gt 0 ] 2>/dev/null; then sync="${sync} ${RED}↓${behind}${RESET}"; fi
    location="$location  ${MAUVE}"$'\xee\x9c\xa5'"${TEAL} $branch"
    if [ -n "$sync" ]; then location="$location  ${sync}"; fi
    location="$location  ${GREEN}+${added}${RESET} ${RED}-${removed}${RESET}"
  fi
fi

version_part=""
if [ -n "$version" ]; then
  version_part="${MAUVE}v${version}${RESET}  "
fi
echo "${version_part}${TEAL}${location}${RESET}"
echo "${BLUE}${model}${RESET}  ${PEACH}${ctx_part}${RESET}  ${duration}"
