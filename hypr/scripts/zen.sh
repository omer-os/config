#!/usr/bin/env bash
# Zen mode: strip the screen down to just the windows -- no waybar, no borders.
# Toggling again restores the normal look. State lives in a flag file so the
# script stays a plain on/off toggle for the keybind.
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-zen"

if [ -e "$STATE" ]; then
  rm -f "$STATE"
  hyprctl eval 'hl.config({ general = { border_size = 1 } })'
  if pgrep -x waybar >/dev/null; then
    pkill -SIGUSR1 -x waybar
  else
    waybar >/dev/null 2>&1 &
  fi
else
  touch "$STATE"
  hyprctl eval 'hl.config({ general = { border_size = 0 } })'
  # SIGUSR1 toggles waybar's visibility without losing its state.
  pgrep -x waybar >/dev/null && pkill -SIGUSR1 -x waybar
  # Dismiss anything swaync is currently showing so the screen is truly empty.
  command -v swaync-client >/dev/null && swaync-client --close-all >/dev/null 2>&1
fi
