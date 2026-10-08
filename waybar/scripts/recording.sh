#!/usr/bin/env bash
# Waybar module: live screen-recording indicator.
#
# Renders nothing at all while idle, so the bar only grows when there is
# genuinely something running. All state comes from screenrecord.sh, which
# owns the recorder; this script never touches the recorder itself.

set -uo pipefail

rec="$HOME/.config/hypr/scripts/screenrecord.sh"

status=$("$rec" status 2>/dev/null) || status=idle

if [[ $status == idle ]]; then
	# Empty text hides the module entirely.
	echo '{"text":"","tooltip":"","class":"idle"}'
	exit 0
fi

secs=$("$rec" elapsed 2>/dev/null)
[[ $secs =~ ^[0-9]+$ ]] || secs=0

if ((secs >= 3600)); then
	clock=$(printf '%d:%02d:%02d' $((secs / 3600)) $((secs % 3600 / 60)) $((secs % 60)))
else
	clock=$(printf '%d:%02d' $((secs / 60)) $((secs % 60)))
fi

out=$(cat "${XDG_RUNTIME_DIR:-/tmp}/screenrecord.path" 2>/dev/null)
out=${out##*/}

if [[ $status == paused ]]; then
	icon="󰏤"
	head="Recording paused"
else
	icon="󰑊"
	head="Recording"
fi

tooltip="<span foreground='#ff5f57'><b>${head}</b></span>  <span foreground='#ededf0'>${clock}</span>"
[[ -n $out ]] && tooltip+="\n<span foreground='#5c5c66'>${out}</span>"
tooltip+="\n\n<span foreground='#5c5c66'>click</span> <span foreground='#a8a8b0'>save</span>"
tooltip+="   <span foreground='#5c5c66'>right</span> <span foreground='#a8a8b0'>pause/resume</span>"

printf '{"text":"%s %s","tooltip":"%s","class":"%s"}\n' "$icon" "$clock" "$tooltip" "$status"
