#!/bin/bash
# Zen Mode Toggle for Hyprland
# Hides waybar and removes gaps/padding/rounding/borders to focus on windows.
# Uses `hyprctl eval` because the Lua config parser disables `hyprctl keyword`.
# Saves/restores values directly (instead of `hyprctl reload`) so monitor
# settings are left alone.

STATE_FILE="/tmp/hypr-zen-mode"

if [ -f "$STATE_FILE" ]; then
  # Disable zen mode — restore saved values
  source "$STATE_FILE"
  hyprctl eval "hl.config({ general = { gaps_in = ${GAPS_IN:-5}, gaps_out = ${GAPS_OUT:-10}, border_size = ${BORDER:-2} }, decoration = { rounding = ${ROUNDING:-12}, active_opacity = ${ACTIVE_OPACITY:-1.0}, inactive_opacity = ${INACTIVE_OPACITY:-1.0}, blur = { enabled = ${BLUR:-true} } } })"
  killall -SIGUSR1 waybar 2>/dev/null # toggle waybar back on
  rm "$STATE_FILE"
  notify-send "Zen Mode" "OFF" -t 1000
else
  # Save current values (gaps are CSS box values like "5 5 5 5" — take first)
  GAPS_IN=$(hyprctl getoption general:gaps_in -j | jq -r '.css // .int' | awk '{print $1}')
  GAPS_OUT=$(hyprctl getoption general:gaps_out -j | jq -r '.css // .int' | awk '{print $1}')
  BORDER=$(hyprctl getoption general:border_size -j | jq -r '.int')
  ROUNDING=$(hyprctl getoption decoration:rounding -j | jq -r '.int')
  ACTIVE_OPACITY=$(hyprctl getoption decoration:active_opacity -j | jq -r '.float')
  INACTIVE_OPACITY=$(hyprctl getoption decoration:inactive_opacity -j | jq -r '.float')
  BLUR=$(hyprctl getoption decoration:blur:enabled -j | jq -r '.bool')

  {
    echo "GAPS_IN=\"$GAPS_IN\""
    echo "GAPS_OUT=\"$GAPS_OUT\""
    echo "BORDER=\"$BORDER\""
    echo "ROUNDING=\"$ROUNDING\""
    echo "ACTIVE_OPACITY=\"$ACTIVE_OPACITY\""
    echo "INACTIVE_OPACITY=\"$INACTIVE_OPACITY\""
    echo "BLUR=\"$BLUR\""
  } >"$STATE_FILE"

  # Enable zen mode — zero out gaps, borders, rounding; kill blur and force full opacity
  hyprctl eval 'hl.config({ general = { gaps_in = 0, gaps_out = 0, border_size = 0 }, decoration = { rounding = 0, active_opacity = 1.0, inactive_opacity = 1.0, blur = { enabled = false } } })'
  killall -SIGUSR1 waybar 2>/dev/null # toggle waybar off
  notify-send "Zen Mode" "ON" -t 1000
fi
