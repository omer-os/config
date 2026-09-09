#!/usr/bin/env bash
# Screenshot, annotate, then save.
#   ALT+S        pick a region  (screenrecord.sh falls through to this when
#                               no recording is live)
#   ALT+SHIFT+S  the whole screen, no selection step
#
# Neither bind writes a file on its own: the shot opens in the editor first,
# where Enter saves it -- and this script copies that same file to the
# clipboard, so one key does what the bare hyprshot binds used to. Ctrl+C
# copies without saving; Escape throws the shot away.
#
# Everything here is picked for latency. grim and slurp are driven directly
# rather than through hyprshot, which cost a flat second per shot in fixed
# sleeps and, worse, tore down its own freeze overlay a beat *after* the
# editor opened -- so the editor spent that beat hidden behind a frozen copy
# of the screen and the shot looked like it had silently failed. The editor is
# swappy rather than satty for the same reason: ~0.14s to a window against
# ~0.75s, measured on this machine. The editor itself is the local build --
# see tools/screenshot-editor -- which adds the Enter bind and trades the side
# panel for a floating toolbar; the packaged swappy is the fallback.

set -uo pipefail

out_dir="$HOME/Pictures/screenshots"

case ${1:-region} in
region | full) mode=$1 ;;
*)
	echo "usage: ${0##*/} {region|full}" >&2
	exit 2
	;;
esac

editor="$HOME/.local/bin/swappy-mini"
[[ -x $editor ]] || editor=swappy

for tool in grim slurp wl-copy "$editor"; do
	command -v "$tool" >/dev/null && continue
	notify-send -a Screenshot "${tool##*/} is not installed" \
		"Install it with: sudo pacman -S ${tool/wl-copy/wl-clipboard}"
	exit 1
done

mkdir -p "$out_dir"

# Clear on-screen notification popups before the capture, so a toast doesn't
# end up baked into the new shot. They stay in the control centre. swaync only
# has a layer surface up while something is actually showing, so the wait for
# it to go away is skipped -- along with its 120ms -- the rest of the time.
popup_showing() {
	hyprctl -j layers 2>/dev/null | grep -q swaync-notification-window
}

if popup_showing; then
	swaync-client --hide-all >/dev/null 2>&1
	fade=1
fi

tmp=$(mktemp -t screenshot-XXXXXXXX.png) || exit 1
trap 'rm -f "$tmp"' EXIT

if [[ $mode == full ]]; then
	monitor=$(hyprctl -j activeworkspace | grep -oP '"monitor":\s*"\K[^"]+')
	[[ -n ${fade:-} ]] && sleep 0.12 # let the popups finish fading out
	grim ${monitor:+-o "$monitor"} "$tmp" || exit 1
else
	# Freeze the screen for the duration of the selection, so a menu or a
	# video can be framed without it moving. hyprpicker -r -z just paints a
	# still copy of every output on top; it is ours to clean up, and it must
	# be gone before the editor opens or it covers it.
	picker=""
	if command -v hyprpicker >/dev/null; then
		hyprpicker -r -z >/dev/null 2>&1 &
		picker=$!
	fi
	sleep 0.2 # freeze overlay maps; also covers the popup fade

	geometry=$(slurp -d -b 00000066 -c ffffffffff -w 2 2>/dev/null)
	if [[ -z $geometry ]]; then
		# Selection cancelled: not an error, just nothing to edit.
		[[ -n $picker ]] && kill "$picker" 2>/dev/null
		exit 0
	fi

	grim -g "$geometry" "$tmp"
	status=$?

	if [[ -n $picker ]]; then
		kill "$picker" 2>/dev/null
		wait "$picker" 2>/dev/null
	fi
	((status == 0)) || exit 1
fi

[[ -s $tmp ]] || exit 1

# Enter (and Ctrl+S) writes into save_dir, set to $out_dir in swappy's config,
# and quits. The editor has no "save and copy" of its own, so anything it
# wrote gets mirrored to the clipboard here -- the marker file dates the run,
# so an older screenshot is never re-copied.
marker=$(mktemp -t screenshot-marker-XXXXXXXX) || exit 1
trap 'rm -f "$tmp" "$marker"' EXIT

"$editor" -f "$tmp"

saved=$(find "$out_dir" -maxdepth 1 -type f -name '*.png' -newer "$marker" -print -quit)
if [[ -n $saved ]]; then
	wl-copy --type image/png <"$saved"
fi
