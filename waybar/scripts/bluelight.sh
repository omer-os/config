#!/usr/bin/env bash
# Toggle the gammastep blue-light (warm) filter on/off.
# Usage: bluelight.sh [temperature]   (default 4000K)

TEMP="${1:-4000}"

note() { command -v notify-send >/dev/null && notify-send -t 1500 "  Blue Light" "$1"; }

if ! command -v gammastep >/dev/null; then
  note "gammastep is not installed.\nInstall it with: sudo pacman -S gammastep"
  exit 1
fi

if pgrep -x gammastep >/dev/null; then
  killall gammastep
  note "Filter off"
else
  gammastep -O "$TEMP" >/dev/null 2>&1 &
  note "Filter on  ·  ${TEMP}K"
fi
