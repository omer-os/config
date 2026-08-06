#!/usr/bin/env bash
# Launch or focus the Waydroid Android UI at a fixed phone-sized window.
# Bound to ALT+SHIFT+A. If the Waydroid window is already open anywhere,
# it gets pulled to the current workspace and focused; otherwise the
# session is started (if needed) and the full UI opens here.

# ---- Android screen size, in Hyprland's logical pixels. Edit these. ----
# Android renders at exactly this resolution and the window comes up at this
# size, so WIDTH is the phone width and HEIGHT should stay at the usable
# screen height (screen height minus the waybar). 446x966 is roughly an
# iPhone 9:19.5 ratio. Changing either value restarts the session on the next
# launch, since Waydroid only reads the size when a session starts.
WIDTH=446
HEIGHT=966
# -----------------------------------------------------------------------

# Full-UI window already open? Bring it here and focus it. Matched exactly,
# since single Waydroid apps show up as "waydroid.<package>" and shouldn't
# be grabbed by this.
addr=$(hyprctl clients -j | jq -r \
  '.[] | select(.class | test("^waydroid$"; "i")) | .address' | head -1)
if [ -n "$addr" ]; then
  # This Hyprland runs the lua config plugin, so hyprctl dispatch takes a lua
  # dispatcher expression -- the plain "movetoworkspace 1,address:.." form is
  # parsed as lua and errors out.
  ws=$(hyprctl activeworkspace -j | jq '.id')
  hyprctl dispatch "hl.dsp.window.move({ workspace = $ws, window = \"address:$addr\" })" >/dev/null
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
  exit 0
fi

if ! command -v waydroid >/dev/null; then
  notify-send "Waydroid" "waydroid is not installed (paru -S waydroid)" -t 4000
  exit 1
fi

# The container is a system service and needs root to start, so just say so
# rather than failing silently on a password prompt with no terminal. Asked
# via systemd, because "waydroid status" only prints its Container line while
# a session is up.
if ! systemctl is-active --quiet waydroid-container; then
  notify-send "Waydroid" "Container is not running: sudo systemctl start waydroid-container" -t 5000
  exit 1
fi

waydroid prop set persist.waydroid.width "$WIDTH"
waydroid prop set persist.waydroid.height "$HEIGHT"

# The props above only take effect when a session starts, so remember the size
# the running session was actually started with and force a restart when the
# values above no longer match it.
state="${XDG_RUNTIME_DIR:-/tmp}/waydroid-ui-size"
want="${WIDTH}x${HEIGHT}"

status=$(waydroid status 2>/dev/null)

# Closing the UI window can leave the session registered as RUNNING while its
# container is actually down. show-full-ui then exits silently and no window
# ever appears, so tear a dead session down before starting a fresh one.
stale=false
grep -q "^Session:.*RUNNING" <<<"$status" \
  && ! grep -q "^Container:.*RUNNING" <<<"$status" && stale=true

if [ "$stale" = true ] || [ "$(cat "$state" 2>/dev/null)" != "$want" ]; then
  waydroid session stop >/dev/null 2>&1
  sleep 1
  status=$(waydroid status 2>/dev/null)
fi

# show-full-ui can start the session itself, but then the session dies with
# whatever launched it. setsid keeps it alive independently. The wait is on
# Container rather than Session because Session flips to RUNNING immediately
# while the container is still coming up.
if ! grep -q "^Container:.*RUNNING" <<<"$status"; then
  notify-send "Waydroid" "Starting session..." -t 2000
  setsid waydroid session start >/dev/null 2>&1 &
  for _ in $(seq 1 60); do
    waydroid status 2>/dev/null | grep -q "^Container:.*RUNNING" && break
    sleep 0.5
  done
fi

echo "$want" >"$state"
setsid waydroid show-full-ui >/dev/null 2>&1 &

# The window is pseudotiled (see the rule in hyprland.lua) so it keeps a fixed
# size inside the tiling layout. Hyprland takes that size from whatever the
# surface happened to be at the moment it mapped, which is mid-startup garbage,
# so pin it to the real size once the window shows up.
for _ in $(seq 1 60); do
  addr=$(hyprctl clients -j | jq -r \
    '.[] | select(.class | test("^waydroid$"; "i")) | .address' | head -1)
  [ -n "$addr" ] && break
  sleep 0.5
done
if [ -n "$addr" ]; then
  sleep 1
  hyprctl dispatch \
    "hl.dsp.window.resize({ x = $WIDTH, y = $HEIGHT, relative = false, window = \"address:$addr\" })" \
    >/dev/null
fi
