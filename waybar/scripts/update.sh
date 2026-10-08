#!/usr/bin/env bash
# Waybar module: weekly system update reminder.
#
# Stays hidden until a week has passed since the last successful update, then
# shows up with the number of pending packages. One click opens a floating
# terminal that runs the whole update (repos + AUR via paru, then flatpak) and
# hides the module again once it finishes. Right click snoozes it for a day.
set -uo pipefail

state="${XDG_STATE_HOME:-$HOME/.local/state}/sysupdate"
mkdir -p "$state"
last="$state/last"       # epoch of the last successful update
snooze="$state/snooze"   # epoch until which the module stays hidden
cache="$state/count"     # cached pending count so status stays cheap

WEEK=$((7 * 24 * 3600))
SIGNAL=12

refresh() { pkill -RTMIN+$SIGNAL waybar 2>/dev/null; }

now=$(date +%s)
last_ts=$(cat "$last" 2>/dev/null || echo 0)

# Also count a full upgrade run outside this module (plain `paru -Syu` in a
# terminal) by reading the last `-Syu` line from the pacman log.
log_line=$(grep -E "\[PACMAN\] Running '(pacman|paru) .*-u" /var/log/pacman.log 2>/dev/null | tail -1)
if [[ -n $log_line ]]; then
  log_ts=$(date -d "${log_line:1:24}" +%s 2>/dev/null || echo 0)
  (( log_ts > last_ts )) && last_ts=$log_ts
fi
snooze_ts=$(cat "$snooze" 2>/dev/null || echo 0)

case "${1:-status}" in

  status)
    if (( now - last_ts < WEEK )) || (( now < snooze_ts )); then
      echo '{"text":"","tooltip":"","class":"idle"}'
      exit 0
    fi

    # Refresh the count at most once an hour; checkupdates hits the mirrors.
    if [[ ! -f $cache ]] || (( now - $(stat -c %Y "$cache") > 3600 )); then
      repo=$(checkupdates 2>/dev/null | wc -l)
      aur=$(paru -Qua 2>/dev/null | wc -l)
      echo $((repo + aur)) > "$cache"
    fi
    n=$(cat "$cache")

    days=$(( (now - last_ts) / 86400 ))
    if (( last_ts == 0 )); then age="never updated from here"
    else age="last update ${days}d ago"; fi

    tooltip="<span foreground='#ededf0'><b>System update</b></span>  <span foreground='#a8a8b0'>${n} packages</span>"
    tooltip+="\n<span foreground='#5c5c66'>${age}</span>"
    tooltip+="\n\n<span foreground='#5c5c66'>click</span> <span foreground='#a8a8b0'>update now</span>"
    tooltip+="   <span foreground='#5c5c66'>right</span> <span foreground='#a8a8b0'>snooze 1 day</span>"

    printf '{"text":"󰚰 %s","tooltip":"%s","class":"due"}\n' "$n" "$tooltip"
    ;;

  # Open the terminal and run the update. The inner shell re-invokes this
  # script's `_inner` step so the logic lives in one file.
  run)
    kitty --class sysupdate-float -e "$0" _inner
    ;;

  _inner)
    g='\e[1;32m'; d='\e[0;32m'; r='\e[1;31m'; x='\e[0m'
    kernel_before=$(pacman -Q linux-cachyos-lts 2>/dev/null)

    printf "${g}==> Repos + AUR (paru -Syu)${x}\n"
    paru -Syu
    pacman_rc=$?

    # The system update is what the reminder is about: mark it done as soon as
    # paru succeeds, so a slow or failed flatpak step (or closing the window
    # while it downloads) doesn't keep the reminder on the bar.
    if (( pacman_rc == 0 )); then
      date +%s > "$last"
      rm -f "$cache" "$snooze"
      refresh
    fi

    printf "\n${g}==> Flatpak${x}\n"
    flatpak update -y
    flatpak_rc=$?

    printf "\n${g}==> Cleaning package cache${x}\n"
    paru -Sc --noconfirm >/dev/null 2>&1

    if (( pacman_rc == 0 && flatpak_rc == 0 )); then
      printf "\n${g}✓ All up to date.${x}\n"
      notify-send -a "System update" "Update finished" "Everything is up to date." 2>/dev/null
    else
      printf "\n${r}✗ Something failed (paru=%s flatpak=%s). Reminder stays on the bar.${x}\n" "$pacman_rc" "$flatpak_rc"
      notify-send -u critical -a "System update" "Update failed" "Check the terminal output." 2>/dev/null
    fi

    if [[ $kernel_before != "$(pacman -Q linux-cachyos-lts 2>/dev/null)" ]]; then
      printf "${d}Kernel was updated - reboot when convenient.${x}\n"
      notify-send -a "System update" "Kernel updated" "Reboot when convenient." 2>/dev/null
    fi

    printf "\n${d}press any key to close${x}"
    read -rsn1
    ;;

  snooze)
    echo $((now + 86400)) > "$snooze"
    refresh
    notify-send -a "System update" "Snoozed" "I'll remind you again tomorrow." 2>/dev/null
    ;;

  # Force the reminder to show right now (for testing, or when you just
  # want to update early).
  show)
    rm -f "$last" "$snooze" "$cache"
    refresh
    ;;

  *)
    echo "usage: update.sh status|run|snooze|show" >&2
    exit 1
    ;;
esac
