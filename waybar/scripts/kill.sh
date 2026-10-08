#!/usr/bin/env bash
# Waybar module: force-stop anything that refuses to close.
#
#   kill.sh status    module text (icon + how many things are stoppable)
#   kill.sh menu      wofi picker: windows, localhost servers, the VM, Waydroid
#   kill.sh focused   kill whatever window has focus right now
#   kill.sh all       stop everything the menu lists, no questions asked
#
# Everything gets SIGTERM first and SIGKILL a few seconds later if it is still
# there, so a well-behaved app gets a chance to save state and a hung one still
# dies. Servers on localhost are killed by process group, so `npm run dev`
# takes its node child with it instead of leaving it holding the port.
set -uo pipefail

SIGNAL=13
refresh() { pkill -RTMIN+$SIGNAL waybar 2>/dev/null; }
notify() { notify-send -a "Kill" -t 2500 "$@" 2>/dev/null; }

# Terminate, then hard-kill after a grace period. $2 = "group" to hit the pgid.
zap() {
  local pid=$1 target=$1
  [[ ${2:-} == group ]] && target="-$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  [[ $target == "-" || -z $target ]] && target=$pid
  kill -TERM -- "$target" 2>/dev/null
  for _ in 1 2 3 4 5 6; do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.5
  done
  kill -KILL -- "$target" 2>/dev/null
}

# --- inventory ---------------------------------------------------------------
# Each line: "<kind>\t<pid>\t<label>". Hidden/special windows are skipped.
windows() {
  hyprctl clients -j 2>/dev/null | jq -r '
    .[] | select(.pid > 0 and .mapped)
    | "win\t\(.pid)\t\(.class)  —  \(.title | .[0:60])"'
}

# Only ports owned by this user show a process in ss, which conveniently hides
# system services (postgres, resolved) that must not be killed from here.
ports() {
  ss -ltnpH 2>/dev/null | while read -r _ _ _ addr _ proc; do
    [[ $proc =~ pid=([0-9]+) ]] || continue
    pid=${BASH_REMATCH[1]}
    name=$(ps -o comm= -p "$pid" 2>/dev/null)
    # Background helpers that happen to listen on a port are not "servers I
    # started" -- kdeconnect backs the phone module, toolbox is JetBrains'.
    case $name in kdeconnectd|jetbrains-toolb*|pipewire*|wireplumber|waydroid*) continue;; esac
    printf 'port\t%s\tlocalhost:%s  —  %s\n' "$pid" "${addr##*:}" "$name"
  done | sort -u -t $'\t' -k2,2
}

vm() {
  local pid
  pid=$(pgrep -o -f '^(/usr/bin/)?qemu-system-x86_64 ' 2>/dev/null) || return 0
  printf 'vm\t%s\tWindows VM (qemu)\n' "$pid"
}

waydroid_running() { waydroid status 2>/dev/null | grep -q 'Session:.*RUNNING'; }
droid() { waydroid_running && printf 'droid\t0\tWaydroid (Android)\n'; }

inventory() { vm; droid; ports; windows; }

# --- act ---------------------------------------------------------------------
do_kill() {
  local kind=$1 pid=$2 label=$3
  case $kind in
    win)   zap "$pid" ;;
    port)  zap "$pid" group ;;
    vm)    pkill -TERM -f quickemu 2>/dev/null; zap "$pid" ;;
    droid) waydroid session stop >/dev/null 2>&1 ;;
  esac
  notify "Stopped" "$label"
}

case "${1:-status}" in

  status)
    n=$(inventory | wc -l)
    tooltip="<span foreground='#ededf0'><b>Force stop</b></span>  <span foreground='#a8a8b0'>${n} running</span>"
    tooltip+="\n\n<span foreground='#5c5c66'>click</span> <span foreground='#a8a8b0'>pick what to stop</span>"
    tooltip+="\n<span foreground='#5c5c66'>right</span> <span foreground='#a8a8b0'>kill focused window</span>"
    tooltip+="\n<span foreground='#5c5c66'>middle</span> <span foreground='#ff5f57'>stop everything</span>"
    printf '{"text":"󱎘","tooltip":"%s","class":"%s"}\n' "$tooltip" "$([[ $n -gt 0 ]] && echo on || echo off)"
    ;;

  menu)
    mapfile -t items < <(inventory)
    if (( ${#items[@]} == 0 )); then notify "Nothing to stop"; exit 0; fi
    {
      for it in "${items[@]}"; do
        kind=${it%%$'\t'*}
        case $kind in vm) i="󰖳";; droid) i="󰀲";; port) i="󰖟";; *) i="󰖯";; esac
        printf '%s  %s\n' "$i" "${it##*$'\t'}"
      done
      printf '󰚌  Stop everything (%d)\n' "${#items[@]}"
    } | wofi --dmenu --prompt "Force stop" --lines 12 2>/dev/null | {
      read -r choice || exit 0
      [[ $choice == *"Stop everything"* ]] && exec "$0" all
      label=${choice#*  }
      for it in "${items[@]}"; do
        if [[ ${it##*$'\t'} == "$label" ]]; then
          IFS=$'\t' read -r kind pid _ <<<"$it"
          do_kill "$kind" "$pid" "$label"
          break
        fi
      done
      refresh
    }
    ;;

  focused)
    read -r pid title < <(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.pid) \(.title)"')
    [[ ${pid:-0} -gt 0 ]] || { notify "No focused window"; exit 0; }
    zap "$pid"
    notify "Killed" "$title"
    refresh
    ;;

  all)
    # Waybar is a window too but has no pid in clients (layer surface), and
    # this script's own terminal isn't spared: that's the point of "all".
    inventory | while IFS=$'\t' read -r kind pid label; do
      do_kill "$kind" "$pid" "$label" &
    done
    wait
    notify "Stopped everything"
    refresh
    ;;

  *)
    echo "usage: kill.sh status|menu|focused|all" >&2
    exit 1
    ;;
esac
