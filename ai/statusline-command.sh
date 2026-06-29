#!/usr/bin/env bash
# Claude Code status line — Starship-inspired style

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
total_cost=$(echo "$input" | jq -r '.total_cost_usd // empty')
five_hour_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch (skip lock to avoid blocking)
git_branch=""
if git_out=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null); then
  git_branch="$git_out"
elif git_out=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" rev-parse --short HEAD 2>/dev/null); then
  git_branch="$git_out"
fi

# ANSI colors (will be dimmed by Claude Code terminal)
bold="\033[1m"
reset="\033[0m"
blue="\033[34m"
cyan="\033[36m"
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
magenta="\033[35m"
white="\033[37m"

# Context color: green > 50%, yellow > 20%, red <= 20%
ctx_color="$green"
ctx_label=""
if [ -n "$used_pct" ]; then
  remaining_int=${remaining_pct%.*}
  remaining_int=${remaining_int:-0}
  if [ "$remaining_int" -le 20 ] 2>/dev/null; then
    ctx_color="$red"
  elif [ "$remaining_int" -le 50 ] 2>/dev/null; then
    ctx_color="$yellow"
  fi
  ctx_label="ctx:${used_pct%.*}%"
fi

# Rate limit color helper: green < 50%, yellow < 80%, red >= 80%
rate_color() {
  local pct_int=${1%.*}
  pct_int=${pct_int:-0}
  if [ "$pct_int" -ge 80 ] 2>/dev/null; then
    printf "%s" "$red"
  elif [ "$pct_int" -ge 50 ] 2>/dev/null; then
    printf "%s" "$yellow"
  else
    printf "%s" "$green"
  fi
}

# Build segments
printf "${bold}${blue} ${short_cwd}${reset}"

if [ -n "$git_branch" ]; then
  printf "  ${bold}${cyan} ${git_branch}${reset}"
fi

if [ -n "$model" ]; then
  printf "  ${bold}${magenta} ${model}${reset}"
fi

if [ -n "$ctx_label" ]; then
  printf "  ${bold}${ctx_color}󰾆 ${ctx_label}${reset}"
fi

if [ -n "$total_cost" ]; then
  cost_fmt=$(printf "%.4f" "$total_cost" 2>/dev/null)
  printf "  ${bold}${white} \$${cost_fmt}${reset}"
fi

if [ -n "$five_hour_pct" ]; then
  color=$(rate_color "$five_hour_pct")
  pct_int=$(printf "%.0f" "$five_hour_pct" 2>/dev/null)
  printf "  ${bold}${color} 5h:${pct_int}%%${reset}"
fi

if [ -n "$seven_day_pct" ]; then
  color=$(rate_color "$seven_day_pct")
  pct_int=$(printf "%.0f" "$seven_day_pct" 2>/dev/null)
  printf "  ${bold}${color} 7d:${pct_int}%%${reset}"
fi

if [ -n "$vim_mode" ]; then
  case "$vim_mode" in
    INSERT)  vim_color="$green"  ; vim_icon="" ;;
    NORMAL)  vim_color="$yellow" ; vim_icon="" ;;
    *)       vim_color="$white"  ; vim_icon="" ;;
  esac
  printf "  ${bold}${vim_color}${vim_icon} ${vim_mode}${reset}"
fi
