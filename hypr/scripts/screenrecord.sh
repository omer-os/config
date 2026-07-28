#!/usr/bin/env bash
# Whole-screen recording, driven from Hyprland binds:
#   ALT+SHIFT+R  start (or stop, if already recording)
#   ALT+P        pause/resume  -- otherwise falls through to `pseudo`
#   ALT+S        stop and save -- otherwise falls through to hyprshot
#
# The fallthrough is the point: ALT+P and ALT+S keep their normal jobs
# unless a recording is genuinely live.

set -uo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
pid_file="$runtime_dir/screenrecord.pid"
path_file="$runtime_dir/screenrecord.path"
pause_file="$runtime_dir/screenrecord.paused"
log_file="$runtime_dir/screenrecord.log"
out_dir="$HOME/Videos/recordings"
framerate=60

notify() {
	# Replace rather than stack, so spamming a bind can't bury the screen.
	notify-send -a "Screen Recorder" \
		-h string:x-canonical-private-synchronous:screenrecord "$@"
}

# Prints the live recorder's pid, or fails. A stale pid file must never
# make ALT+P/ALT+S think a recording exists, and a recycled pid must never
# get signalled, so verify the pid really is our recorder.
recorder_pid() {
	local pid cmd
	[[ -r $pid_file ]] || return 1
	pid=$(<"$pid_file") || return 1
	[[ $pid =~ ^[0-9]+$ ]] || return 1
	[[ -r /proc/$pid/cmdline ]] || return 1
	cmd=$(tr '\0' '\n' <"/proc/$pid/cmdline" 2>/dev/null | head -1) || return 1
	[[ ${cmd##*/} == gpu-screen-recorder ]] || return 1
	printf '%s' "$pid"
}

clear_state() {
	rm -f "$pid_file" "$path_file" "$pause_file"
}

start() {
	if recorder_pid >/dev/null; then
		notify "Already recording"
		return
	fi

	if ! command -v gpu-screen-recorder >/dev/null; then
		notify "gpu-screen-recorder is not installed" \
			"Install it with: sudo pacman -S gpu-screen-recorder"
		return 1
	fi

	mkdir -p "$out_dir"
	local out="$out_dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

	clear_state
	gpu-screen-recorder -w screen -f "$framerate" -o "$out" \
		>"$log_file" 2>&1 &
	local pid=$!
	printf '%s' "$pid" >"$pid_file"
	printf '%s' "$out" >"$path_file"

	# It can die instantly on a bad capture target; report that rather than
	# leaving the user to discover ALT+S does nothing.
	sleep 0.5
	if ! recorder_pid >/dev/null; then
		clear_state
		notify "Recording failed to start" "See $log_file"
		return 1
	fi

	notify "Recording started" "ALT+P pause · ALT+S save"
}

toggle_pause() {
	local pid=$1
	kill -USR2 "$pid" || return 1
	if [[ -e $pause_file ]]; then
		rm -f "$pause_file"
		notify "Recording resumed"
	else
		: >"$pause_file"
		notify "Recording paused"
	fi
}

save() {
	local pid=$1
	local out
	out=$(cat "$path_file" 2>/dev/null)

	# Finalising from a paused encoder is asking for a truncated file;
	# resume first, then stop.
	if [[ -e $pause_file ]]; then
		kill -USR2 "$pid" 2>/dev/null
		sleep 0.3
	fi

	kill -INT "$pid" 2>/dev/null

	# SIGINT makes it flush and write the moov atom; that takes a moment.
	local i
	for i in {1..100}; do
		[[ -d /proc/$pid ]] || break
		sleep 0.1
	done

	clear_state

	if [[ -s $out ]]; then
		notify "Recording saved" "${out/#$HOME/~}"
	else
		notify "Recording stopped" "No file was written — see $log_file"
	fi
}

case ${1:-toggle} in
toggle)
	if pid=$(recorder_pid); then
		save "$pid"
	else
		start
	fi
	;;
start)
	start
	;;
pause)
	if pid=$(recorder_pid); then
		toggle_pause "$pid"
	else
		hyprctl dispatch pseudo
	fi
	;;
save)
	if pid=$(recorder_pid); then
		save "$pid"
	else
		hyprshot -m region
	fi
	;;
status)
	# For a waybar module, if you ever want one.
	if recorder_pid >/dev/null; then
		[[ -e $pause_file ]] && echo paused || echo recording
	else
		echo idle
	fi
	;;
*)
	echo "usage: ${0##*/} {toggle|start|pause|save|status}" >&2
	exit 2
	;;
esac
