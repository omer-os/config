#!/usr/bin/env bash
# Now-playing for Waybar (JSON). Outputs nothing-visible when no player is active.

status=$(playerctl status 2>/dev/null)
if [ -z "$status" ]; then
  echo '{"text":"","tooltip":"","class":"stopped"}'
  exit 0
fi

artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)
album=$(playerctl metadata album 2>/dev/null)

[ -z "$title" ] && title="Unknown"
if [ -n "$artist" ]; then
  label="$artist — $title"
else
  label="$title"
fi

# Trim long labels
max=42
if [ "${#label}" -gt "$max" ]; then
  label="${label:0:max}…"
fi

case "$status" in
  Playing) icon="" ; cls="playing" ;;
  Paused)  icon="" ; cls="paused"  ;;
  *)       icon="" ; cls="stopped" ;;
esac

# pango-escape (text field is parsed as markup)
pango() { printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
# json-escape
json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

text=$(json "$(pango "$icon  $label")")
tip=$(json "$(pango "$title\n$artist\n$album")")

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tip" "$cls"
