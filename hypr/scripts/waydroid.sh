#!/usr/bin/env bash
# Launch, focus, and resize the Waydroid Android UI as a phone-sized window.
#
#   waydroid.sh              launch or focus the phone      (ALT+SHIFT+A)
#   waydroid.sh size         pick a size from a menu        (ALT+SHIFT+P)
#   waydroid.sh size 500x1000  set a size directly
#   waydroid.sh adb          just (re)connect adb
#
# The window is floating and pinned to an exact size by the "waydroid-phone"
# rule in hyprland.lua. It used to be pseudotiled, which is what made the width
# reset whenever it moved: Hyprland rescales a pseudotiled window to fit the
# tile it currently sits in, so landing on a busier workspace shrank the phone.
# Floating windows keep their size no matter where they are dragged.
#
# Size is a two-part thing and both parts have to agree:
#   - persist.waydroid.{width,height} decide what Android renders at,
#   - the "size" line of the hyprland.lua rule decides how big the window is.
# So "waydroid.sh size" writes both, and hyprland.lua is the source of truth for
# what the current size is. Android only reads those props when a session
# starts, so a size change restarts the session -- there is no live path for it.
# (Its HWC calls choose_width_height() once at display init and the display
# advertises exactly one mode.) Dragging the window edge cannot reflow Android;
# that is why resizing is a command instead of a drag.

set -uo pipefail

LUA="$HOME/.config/hypr/hyprland.lua"
# Side margin only. The phone stands full-height in the area waybar leaves --
# 966 of the 968 usable logical pixels here -- so there is no room to inset it
# vertically without making it smaller than the screen allows.
GAP=20

notify() { notify-send "Waydroid" "$1" -t "${2:-4000}"; }

die() {
  notify "$1" 6000
  echo "waydroid.sh: $1" >&2
  exit 1
}

# --- window lookup -----------------------------------------------------------
# Matched exactly: individual Waydroid apps show up as "waydroid.<package>" and
# must not be grabbed by this.
find_window() {
  hyprctl clients -j | jq -r \
    '.[] | select(.class | test("^waydroid$"; "i")) | .address' | head -1
}

# This Hyprland uses the lua config, so hyprctl dispatch takes a lua dispatcher
# expression -- the plain "movetoworkspace 1,address:.." form is parsed as lua
# and errors out.
focus_window() {
  local addr=$1 ws
  ws=$(hyprctl activeworkspace -j | jq '.id')
  hyprctl dispatch "hl.dsp.window.move({ workspace = $ws, window = \"address:$addr\" })" >/dev/null
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
}

# --- size --------------------------------------------------------------------
# The rule lines carry marker comments so this can rewrite them without having
# to parse lua.
current_size() {
  sed -n 's/.*size *= *"\([0-9]* [0-9]*\)".*-- waydroid-size.*/\1/p' "$LUA" | head -1
}

# Usable logical area of the monitor the cursor is on: physical size divided by
# the fractional scale, minus whatever waybar reserved.
monitor_usable() {
  hyprctl monitors -j | jq -r '
    (map(select(.focused)) | first) // .[0]
    | [ ((.width / .scale) - .reserved[0] - .reserved[2] | floor),
        ((.height / .scale) - .reserved[1] - .reserved[3] | floor),
        .reserved[1] ]
    | @tsv'
}

# Shrink w/h to fit the usable area, keeping the aspect ratio so the phone never
# ends up a weird shape or hanging off the screen.
clamp_size() {
  local w=$1 h=$2 maxw maxh
  read -r maxw maxh _ < <(monitor_usable)
  maxw=$((maxw - 2 * GAP))
  if [ "$w" -gt "$maxw" ] || [ "$h" -gt "$maxh" ]; then
    # integer scale-to-fit: pick the tighter of the two ratios
    if [ $((w * maxh)) -gt $((h * maxw)) ]; then
      h=$((h * maxw / w))
      w=$maxw
    else
      w=$((w * maxh / h))
      h=$maxh
    fi
  fi
  echo "$w $h"
}

# Rewrite the two marked lines in hyprland.lua and reload. The move expression
# has to track the width so the phone stays docked to the right edge.
write_lua_size() {
  local w=$1 h=$2 top
  read -r _ _ top < <(monitor_usable)
  local x=$((w + GAP)) y=$top

  sed -i \
    -e "s/\(size *= *\)\"[0-9]* [0-9]*\"\(.*-- waydroid-size\)/\1\"$w $h\"\2/" \
    -e "s/\(move *= *\)\"[^\"]*\"\(.*-- waydroid-move\)/\1\"monitor_w-$x $y\"\2/" \
    "$LUA"

  hyprctl reload >/dev/null
}

set_size() {
  local spec=$1 w h
  if ! [[ $spec =~ ^([0-9]+)x([0-9]+)$ ]]; then
    die "Bad size \"$spec\" -- expected WIDTHxHEIGHT, e.g. 446x966"
  fi
  read -r w h < <(clamp_size "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")

  write_lua_size "$w" "$h"

  # These are persistent Android properties, so they have to be written while a
  # session is actually up -- "waydroid prop set" talks to the container. They
  # then survive in /data and are what the next session boots at.
  if waydroid status 2>/dev/null | grep -q "^Session:.*RUNNING"; then
    waydroid prop set persist.waydroid.width "$w" >/dev/null 2>&1
    waydroid prop set persist.waydroid.height "$h" >/dev/null 2>&1

    # Android reads them only at display init, so it has to come back up for the
    # new resolution to take effect. There is no live resize path.
    notify "Resizing to ${w}x${h} -- restarting Android..." 3000
    waydroid session stop >/dev/null 2>&1
    # Wait for the old window to actually go away, otherwise launch() finds it
    # and just focuses the stale one at the old size.
    for _ in $(seq 1 30); do
      [ -z "$(find_window)" ] && break
      sleep 0.5
    done
  else
    notify "Size set to ${w}x${h}" 3000
  fi
  launch
}

# Presets are clamped to the monitor, so "Tablet" stays sane on a small screen.
pick_size() {
  local choice
  choice=$(printf '%s\n' \
    "Compact   400x866" \
    "Phone     446x966" \
    "Large     520x966" \
    "Tablet    800x966" \
    | wofi --dmenu --prompt "Waydroid size" 2>/dev/null) || exit 0
  [ -n "$choice" ] || exit 0
  set_size "$(awk '{print $NF}' <<<"$choice")"
}

# --- adb ---------------------------------------------------------------------
# auto_adb (set by waydroid-setup.sh) connects once when Android finishes
# booting, but Android Studio restarts the adb server fairly often and that
# drops the connection. Reconnecting on every launch/focus covers that case --
# it is the other half of "the device sometimes isn't in Device Manager".
container_ip() {
  waydroid status 2>/dev/null | awk '/^IP address:/ {print $3}' | grep -Ex '([0-9]{1,3}\.){3}[0-9]{1,3}'
}

adb_connect() {
  command -v adb >/dev/null || return 0

  local ip=""
  for _ in $(seq 1 "${1:-1}"); do
    ip=$(container_ip) && [ -n "$ip" ] && break
    sleep 1
  done

  if [ -z "$ip" ]; then
    # Waydroid reads this from the dnsmasq lease file, so an empty answer means
    # Android never got a DHCP lease -- almost always the firewall.
    return 1
  fi

  adb devices 2>/dev/null | grep -q "^$ip:5555[[:space:]]*device" && return 0
  adb connect "$ip:5555" >/dev/null 2>&1
  adb devices 2>/dev/null | grep -q "^$ip:5555[[:space:]]*device"
}

# --- launch ------------------------------------------------------------------
launch() {
  local size w h addr status stale=false

  size=$(current_size)
  [ -n "$size" ] || die "Could not read the size from the waydroid-phone rule in hyprland.lua"
  read -r w h <<<"$size"

  # Already open? Pull it here, focus it, make sure adb is still attached.
  addr=$(find_window)
  if [ -n "$addr" ]; then
    focus_window "$addr"
    adb_connect 1 || true
    exit 0
  fi

  command -v waydroid >/dev/null || die "waydroid is not installed (paru -S waydroid)"

  # The container is a system service and needs root to start, so say so rather
  # than failing on a password prompt with no terminal attached. Asked via
  # systemd because "waydroid status" only prints its Container line while a
  # session is up.
  systemctl is-active --quiet waydroid-container ||
    die "Container is not running: sudo systemctl start waydroid-container"

  status=$(waydroid status 2>/dev/null)

  # Closing the UI window can leave the session registered as RUNNING while its
  # container is actually down. show-full-ui then exits silently and no window
  # ever appears, so tear a dead session down before starting a fresh one.
  grep -q "^Session:.*RUNNING" <<<"$status" &&
    ! grep -q "^Container:.*RUNNING" <<<"$status" && stale=true

  if [ "$stale" = true ]; then
    waydroid session stop >/dev/null 2>&1
    sleep 1
    status=$(waydroid status 2>/dev/null)
  fi

  # show-full-ui can start the session itself, but then the session dies with
  # whatever launched it. setsid keeps it alive independently. The wait is on
  # Container rather than Session because Session flips to RUNNING immediately
  # while the container is still coming up.
  if ! grep -q "^Container:.*RUNNING" <<<"$status"; then
    notify "Starting Android..." 2500
    setsid waydroid session start >/dev/null 2>&1 &
    for _ in $(seq 1 60); do
      waydroid status 2>/dev/null | grep -q "^Container:.*RUNNING" && break
      sleep 0.5
    done
  fi

  # Now that the container is up these will stick. They are persistent props, so
  # this is really about the first ever launch: if Android booted at some other
  # resolution than the rule expects, writing them here means the next launch
  # comes up matching instead of staying wrong forever.
  waydroid prop set persist.waydroid.width "$w" >/dev/null 2>&1
  waydroid prop set persist.waydroid.height "$h" >/dev/null 2>&1

  setsid waydroid show-full-ui >/dev/null 2>&1 &

  # The window rule sizes and places it on map, so there is nothing to fix up
  # here -- just wait for it so we can pull it to the current workspace.
  for _ in $(seq 1 60); do
    addr=$(find_window)
    [ -n "$addr" ] && break
    sleep 0.5
  done
  [ -n "$addr" ] || die "Waydroid window never appeared. Check: waydroid log"

  focus_window "$addr"

  # Android is still booting at this point; the lease and adb take a while.
  if ! adb_connect 45; then
    notify "Android is up, but adb never connected.
No DHCP lease -- run: sudo ~/.config/hypr/scripts/waydroid-setup.sh" 8000
  fi
}

case "${1:-}" in
"") launch ;;
size)
  if [ -n "${2:-}" ]; then set_size "$2"; else pick_size; fi
  ;;
adb)
  adb_connect 5 && notify "adb connected" 2500 || die "adb could not connect -- no container IP (no DHCP lease?)"
  ;;
*) die "Unknown command \"$1\" -- use: (nothing) | size [WxH] | adb" ;;
esac
