#!/usr/bin/env bash
# Tools quick-menu for Waybar.

if pgrep -x gammastep >/dev/null; then bl="On"; else bl="Off"; fi

chosen=$(printf "%s\n" \
  "  Blue Light   [$bl]" \
  "  Blue Light · Warmer (3400K)" \
  "  Color Picker" \
  "  Screenshot" \
  "  Clipboard History" \
  "  Audio Visualizer" \
  "  System Monitor" \
  "  Bluetooth" \
  "  Displays" |
  wofi --dmenu --prompt "Tools" --width 300 --height 380)

case "$chosen" in
*"Blue Light · Warmer"*) ~/.config/waybar/scripts/bluelight.sh 3400 ;;
*"Blue Light"*)          ~/.config/waybar/scripts/bluelight.sh 4000 ;;
*"Color Picker"*)        sleep 0.2; hyprpicker -a ;;
*"Screenshot"*)          hyprshot -m region ;;
*"Clipboard History"*)   cliphist list | wofi --dmenu | cliphist decode | wl-copy ;;
*"Audio Visualizer"*)    kitty --class cava-float -e cava ;;
*"System Monitor"*)      kitty --class btop-float -e btop ;;
*"Bluetooth"*)           blueman-manager ;;
*"Displays"*)            wdisplays ;;
esac
