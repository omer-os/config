#!/usr/bin/env bash
# Toggle the laptop screen on/off via Hyprland's own monitor config.
# Using `hyprctl eval` (instead of wlr-randr) keeps the off-state in Hyprland's
# view, so other config evals (e.g. zen mode) don't re-enable the screen.
#   toggle-eDP.sh          toggle (ALT + SHIFT + D)
#   toggle-eDP.sh rescue   turn the panel back on if it is the only screen left
#                          (run by hyprland.lua whenever a monitor goes away)
#
# The panel only goes off while another screen is up, so there is always
# something to look at. While it is off a flag file names it; hyprland.lua
# reads that on every config reload, which would otherwise switch it back on.
FLAG="${XDG_RUNTIME_DIR:-/tmp}/hypr/$HYPRLAND_INSTANCE_SIGNATURE/laptop-screen-off"

notify() {
  notify-send -a "Display" -i "$1" -t "${4:-2500}" \
    -h string:x-canonical-private-synchronous:display "$2" "$3"
}

# Sets panel (the built-in screen's name), panel_off and externals (how many
# other screens are currently on).
read_state() {
  local mons
  mons=$(hyprctl monitors all -j) || exit 1
  panel=$(jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)"))][0].name // empty' <<<"$mons")
  panel_off=$(jq -r --arg p "$panel" '.[] | select(.name == $p) | .disabled' <<<"$mons")
  externals=$(jq --arg p "$panel" \
    '[.[] | select(.name != $p and .name != "FALLBACK" and (.disabled | not))] | length' <<<"$mons")
}

apply() {
  local out
  out=$(hyprctl eval "hl.monitor($1)" 2>&1)
  [ "$out" = "ok" ] && return 0
  notify dialog-error "Laptop screen" "Hyprland refused the change: $out" 6000
  return 1
}

panel_on() {
  rm -f "$FLAG"
  apply "{ output = \"$panel\", disabled = false, mode = \"preferred\", position = \"auto\", scale = \"auto\" }"
}

panel_off() {
  echo "$panel" >"$FLAG"
  apply "{ output = \"$panel\", disabled = true }" || { rm -f "$FLAG"; return 1; }
}

# A held key or a double press must not flip the screen twice.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/toggle-eDP.lock"

if [ "$1" = "rescue" ]; then
  flock 9
  # The unplugged monitor can still be listed for a moment after the event.
  for _ in 1 2 3 4 5; do
    read_state
    [ "$panel_off" = "true" ] && [ "$externals" -eq 0 ] && break
    sleep 0.3
  done
  if [ -n "$panel" ] && [ "$panel_off" = "true" ] && [ "$externals" -eq 0 ]; then
    panel_on && notify computer-laptop "Laptop screen back on" "The external monitor was disconnected."
  fi
  exit 0
fi

flock -n 9 || exit 0
read_state

if [ -z "$panel" ]; then
  notify dialog-warning "No laptop screen" "This machine has no built-in display to toggle." 3500
elif [ "$panel_off" = "true" ]; then
  panel_on && notify computer-laptop "Laptop screen on" "$panel is back."
elif [ "$externals" -eq 0 ]; then
  notify dialog-warning "No monitor to switch to" \
    "Connect an external monitor first. The laptop screen stays on." 3500
else
  panel_off && notify video-display "Laptop screen off" "Press ALT + SHIFT + D to turn it back on."
fi
