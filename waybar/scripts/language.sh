#!/usr/bin/env bash
# Keyboard-layout indicator + toggle for waybar.
#   no args  -> print current layout as JSON for the custom/language module
#   toggle   -> switch us <-> ara, then refresh the waybar module instantly

emit() {
  local km
  km=$(hyprctl -j devices 2>/dev/null \
    | jq -r 'first(.keyboards[] | select(.main==true) | .active_keymap) // .keyboards[-1].active_keymap')
  case "$km" in
    *rabic*|*ara*)
      printf '{"text":"AR","alt":"ar","tooltip":"العربية · click to switch","class":"ar"}\n' ;;
    *)
      printf '{"text":"EN","alt":"en","tooltip":"English · click to switch","class":"en"}\n' ;;
  esac
}

case "$1" in
  toggle)
    hyprctl switchxkblayout all next >/dev/null 2>&1
    pkill -RTMIN+8 waybar 2>/dev/null  # signal 8 -> instant refresh
    ;;
  *)
    emit ;;
esac
