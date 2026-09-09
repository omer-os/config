#!/usr/bin/env bash
# Click actions for the right-hand waybar modules. Every one of these is a
# toggle or a cycle, so a single click does something useful and the OSD /
# notification tells you what happened.
set -u

notify() { notify-send -a waybar -t 1500 -h string:x-canonical-private-synchronous:waybar "$@"; }
refresh() { pkill -RTMIN+"$1" waybar 2>/dev/null; }

case "${1:-}" in

  # Cycle power-profiles-daemon: power-saver -> balanced -> performance -> ...
  profile)
    current=$(powerprofilesctl get 2>/dev/null)
    mapfile -t profiles < <(powerprofilesctl list 2>/dev/null | grep -oP '^\s*\*?\s*\K[a-z-]+(?=:)')
    [ "${#profiles[@]}" -eq 0 ] && exit 0
    next=${profiles[0]}
    for i in "${!profiles[@]}"; do
      if [ "${profiles[$i]}" = "$current" ]; then
        next=${profiles[$(( (i + 1) % ${#profiles[@]} ))]}
        break
      fi
    done
    powerprofilesctl set "$next" && notify "Power profile" "$next"
    ;;

  # Move audio to the next available sink.
  sink)
    ids=$(wpctl status | sed -n '/Sinks:/,/Sources:/p' | grep -oP '^[^0-9]*\K[0-9]+(?=\.)')
    [ -z "$ids" ] && exit 0
    default=$(wpctl inspect @DEFAULT_AUDIO_SINK@ | head -1 | grep -oP 'id \K[0-9]+')
    next=$(echo "$ids" | awk -v cur="$default" '{a[NR]=$0} END{for(i=1;i<=NR;i++) if(a[i]==cur){print a[i%NR+1]; exit} print a[1]}')
    wpctl set-default "$next"
    notify "Audio output" "$(wpctl inspect "$next" | grep -oP 'node.description = "\K[^"]+' | head -1)"
    ;;

  # Bluetooth radio on/off.
  bt)
    if bluetoothctl show | grep -q 'Powered: yes'; then
      bluetoothctl power off >/dev/null && notify "Bluetooth" "off"
    else
      rfkill unblock bluetooth 2>/dev/null
      bluetoothctl power on >/dev/null && notify "Bluetooth" "on"
    fi
    ;;

  # Wi-Fi radio on/off.
  wifi)
    if [ "$(nmcli radio wifi)" = "enabled" ]; then
      nmcli radio wifi off && notify "Wi-Fi" "off"
    else
      nmcli radio wifi on && notify "Wi-Fi" "on"
    fi
    ;;

  # Brightness: click jumps between a comfortable dim and full.
  brightness)
    pct=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%')
    if [ "${pct:-100}" -gt 60 ]; then
      brightnessctl -e4 -n2 set 30% >/dev/null
    else
      brightnessctl -e4 -n2 set 100% >/dev/null
    fi
    ;;

  *)
    echo "usage: actions.sh profile|sink|bt|wifi|brightness" >&2
    exit 1
    ;;
esac
