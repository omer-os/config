#!/usr/bin/env bash
# Waybar module + click action: push the clipboard to the phone over wifi.
#
# KDE Connect does the transport. `status` renders the module (dim when no
# paired phone is reachable, bright when one is), `send` fires on click and
# picks what to do from the clipboard's own MIME types: an image or a copied
# file goes over as a file, anything else goes over as text.

set -uo pipefail

cli=kdeconnect-cli
stash="${XDG_RUNTIME_DIR:-/tmp}/waybar-phone"

notify() { notify-send -a waybar -t 2500 -h string:x-canonical-private-synchronous:phone "$@"; }

# First reachable paired device. Empty if the phone is off, asleep or on
# another network.
device() { "$cli" -a --id-only 2>/dev/null | head -1; }

name_of() {
	"$cli" -a 2>/dev/null | sed -n "s/^- \(.*\): $1 .*/\1/p" | head -1
}

# Extension for the clipboard's image type, so the phone's gallery picks the
# file up instead of treating it as an unknown blob.
ext_for() {
	case "$1" in
		image/png) echo png ;;
		image/jpeg) echo jpg ;;
		image/webp) echo webp ;;
		image/gif) echo gif ;;
		image/bmp) echo bmp ;;
		image/tiff) echo tiff ;;
		image/svg+xml) echo svg ;;
		*) echo bin ;;
	esac
}

case "${1:-status}" in

status)
	id=$(device)
	if [[ -z $id ]]; then
		echo '{"text":"󰄰","tooltip":"No phone reachable\nclick: pair or check wifi","class":"off"}'
		exit 0
	fi
	name=$(name_of "$id")
	echo "{\"text\":\"󰄞\",\"tooltip\":\"${name:-Phone} connected\nclick: send clipboard   middle: ring   right: settings\",\"class\":\"on\"}"
	;;

send)
	id=$(device)
	if [[ -z $id ]]; then
		notify "Phone" "Nothing reachable — check that both are on the same wifi"
		exit 1
	fi
	name=$(name_of "$id")
	name=${name:-phone}

	types=$(wl-paste -l 2>/dev/null)
	img=$(grep -m1 '^image/' <<<"$types")

	if [[ -n $img ]]; then
		mkdir -p "$stash"
		file="$stash/clip-$(date +%Y%m%d-%H%M%S).$(ext_for "$img")"
		wl-paste -t "$img" > "$file" || { notify "Phone" "Could not read the clipboard image"; exit 1; }
		"$cli" -d "$id" --share "$file" && notify "Sent to $name" "${file##*/}"

	elif grep -qx 'text/uri-list' <<<"$types"; then
		# Something copied out of a file manager: send the files themselves.
		sent=0
		while IFS= read -r uri; do
			[[ $uri == file://* ]] || continue
			path=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.unquote(sys.argv[1][7:]))' "${uri%$'\r'}")
			[[ -f $path ]] || continue
			"$cli" -d "$id" --share "$path" && sent=$((sent + 1))
		done < <(wl-paste -t text/uri-list 2>/dev/null)
		if ((sent > 0)); then
			notify "Sent to $name" "$sent file(s)"
		else
			notify "Phone" "No readable files in the clipboard"
		fi

	else
		text=$(wl-paste -n 2>/dev/null)
		if [[ -z $text ]]; then
			notify "Phone" "Clipboard is empty"
			exit 1
		fi
		"$cli" -d "$id" --share-text "$text" && notify "Sent to $name" "${text:0:60}"
	fi

	pkill -RTMIN+11 waybar 2>/dev/null
	;;

ring)
	id=$(device) || exit 0
	[[ -n $id ]] && "$cli" -d "$id" --ring && notify "Phone" "Ringing"
	;;

settings)
	if command -v kdeconnect-app >/dev/null; then kdeconnect-app &
	else kdeconnect-settings & fi
	;;

esac
