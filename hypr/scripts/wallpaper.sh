#!/bin/bash
# Wallpaper switcher for Hyprland (uses `awww`, CachyOS's swww package).
# Picks a random wallpaper from WALL_DIR and applies it with a transition.
# Remembers the last choice so it can be restored on login.
#
# Usage:
#   wallpaper.sh            pick a new random wallpaper (different from current)
#   wallpaper.sh restore    re-apply the last wallpaper (used at startup)
#   wallpaper.sh <path>     set a specific image

WALL_DIR="$HOME/Pictures/wallpapers"
STATE_FILE="$HOME/.cache/current-wallpaper"

# Make sure the daemon is up before we send it images.
if ! pgrep -x awww-daemon >/dev/null 2>&1; then
  awww-daemon &
  sleep 0.5
fi

apply() {
  local img="$1"
  awww img "$img" \
    --transition-type grow \
    --transition-pos "$(hyprctl cursorpos 2>/dev/null | tr -d ' ' || echo center)" \
    --transition-fps 60 \
    --transition-duration 1.2
  echo "$img" >"$STATE_FILE"
}

case "$1" in
restore)
  # Re-apply saved wallpaper; fall back to a random one if none saved.
  if [ -s "$STATE_FILE" ] && [ -f "$(cat "$STATE_FILE")" ]; then
    awww img "$(cat "$STATE_FILE")" --transition-type none
  else
    exec "$0"
  fi
  ;;
"")
  # Random pick, excluding the current wallpaper so it always changes.
  current="$(cat "$STATE_FILE" 2>/dev/null)"
  mapfile -d '' -t walls < <(find "$WALL_DIR" -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) -print0)

  if [ ${#walls[@]} -eq 0 ]; then
    notify-send "Wallpaper" "No images in $WALL_DIR" -t 2000
    exit 1
  fi

  if [ ${#walls[@]} -gt 1 ]; then
    walls=("${walls[@]/$current/}") # drop current from the pool
  fi

  pick="${walls[RANDOM % ${#walls[@]}]}"
  [ -z "$pick" ] && pick="$current" # safety net
  apply "$pick"
  notify-send "Wallpaper" "$(basename "$pick")" -t 1500
  ;;
*)
  # Explicit path.
  if [ -f "$1" ]; then
    apply "$1"
  else
    notify-send "Wallpaper" "Not found: $1" -t 2000
    exit 1
  fi
  ;;
esac
