#!/usr/bin/env bash
# Zen mode: strip the screen down to just the windows -- no waybar, no borders,
# no gaps, and none of the frosted-glass styling (blur, transparency, shadows,
# rounded corners). Toggling again restores the normal look. State lives in a
# flag file so the script stays a plain on/off toggle for the keybind.
STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr-zen"

# kitty draws its own translucency on top of Hyprland's, so it has to be told
# separately. Each kitty listens on @kitty-<pid> (see kitty/kitty.conf).
kitty_opacity() {
  local pid
  for pid in $(pgrep -x kitty); do
    kitty @ --to "unix:@kitty-$pid" set-background-opacity --all "$1" >/dev/null 2>&1
  done
}

if [ -e "$STATE" ]; then
  rm -f "$STATE"
  # Keep in sync with general/decoration in hyprland.lua.
  hyprctl eval 'hl.config({
    general = { border_size = 1, gaps_in = 5, gaps_out = 10 },
    decoration = {
      rounding = 6, active_opacity = 0.86, inactive_opacity = 0.76,
      shadow = { enabled = true }, blur = { enabled = true },
    },
  })'
  kitty_opacity default
  if pgrep -x waybar >/dev/null; then
    pkill -SIGUSR1 -x waybar
  else
    waybar >/dev/null 2>&1 &
  fi
else
  touch "$STATE"
  hyprctl eval 'hl.config({
    general = { border_size = 0, gaps_in = 0, gaps_out = 0 },
    decoration = {
      rounding = 0, active_opacity = 1.0, inactive_opacity = 1.0,
      shadow = { enabled = false }, blur = { enabled = false },
    },
  })'
  kitty_opacity 1
  # SIGUSR1 toggles waybar's visibility without losing its state.
  pgrep -x waybar >/dev/null && pkill -SIGUSR1 -x waybar
  # Dismiss anything swaync is currently showing so the screen is truly empty.
  command -v swaync-client >/dev/null && swaync-client --close-all >/dev/null 2>&1
fi
