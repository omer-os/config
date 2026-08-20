#!/usr/bin/env bash
# Launch or focus the Windows 11 VM (quickemu/KVM).
# Bound to ALT+SHIFT+W. If the VM window is already open anywhere,
# it gets pulled to the current workspace and focused; otherwise the
# VM is booted and its window is moved here once it maps.

VM_DIR="$HOME/VMs"
CONF="windows-11.conf"
DISK="$VM_DIR/windows-11/disk.qcow2"
LOG="${XDG_RUNTIME_DIR:-/tmp}/win11-launch.log"

# The VM window class. With display="spice" the window belongs to the SPICE
# client (spicy, app id org.spice.spicy), not to qemu -- qemu itself runs
# headless. "^qemu" is kept for the old gtk-display path and for a bare
# quickemu run. Match the class only: the version before this also matched
# .title, which meant any window merely titled something with "qemu" in it got
# yanked here.
CLASS_RE="^(org\.spice\.spicy|spicy|remote-viewer|virt-viewer|qemu)"

focus_window() {
  # This Hyprland runs the lua config plugin, so hyprctl dispatch takes a lua
  # dispatcher expression -- the plain "movetoworkspace 1,address:.." form is
  # parsed as lua and errors out.
  local addr=$1
  local ws
  ws=$(hyprctl activeworkspace -j | jq '.id')
  hyprctl dispatch "hl.dsp.window.move({ workspace = $ws, window = \"address:$addr\" })" >/dev/null
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
}

find_window() {
  hyprctl clients -j | jq -r \
    --arg re "$CLASS_RE" '.[] | select(.class | test($re; "i")) | .address' | head -1
}

# VM window already open? Bring it here and focus it.
addr=$(find_window)
if [ -n "$addr" ]; then
  focus_window "$addr"
  exit 0
fi

if ! command -v quickemu >/dev/null; then
  notify-send "Windows 11" "quickemu is not installed (paru -S quickemu)" -t 4000
  exit 1
fi

# The VM is display="spice", so the window comes from the SPICE client rather
# than from qemu. Without a client installed quickemu boots the VM headless and
# nothing ever maps, which looks identical to a hung boot.
if ! command -v spicy >/dev/null && ! command -v remote-viewer >/dev/null; then
  notify-send "Windows 11" "No SPICE client: sudo pacman -S spice-gtk" -t 6000
  exit 1
fi

if [ ! -f "$VM_DIR/$CONF" ]; then
  notify-send "Windows 11" "VM not set up yet: cd ~/VMs && quickget windows 11" -t 5000
  exit 1
fi

# An untouched qcow2 is a couple hundred KB. Booting that just drops you at a
# UEFI shell with no hint as to why, so check before spending 30s on it.
if [ -f "$DISK" ] && [ "$(stat -c %s "$DISK")" -lt 1048576 ]; then
  notify-send "Windows 11" "Disk is empty -- Windows isn't installed yet. Run: cd ~/VMs && quickemu --vm $CONF" -t 6000
  exit 1
fi

notify-send "Windows 11" "Booting VM..." -t 2000
cd "$VM_DIR" || exit 1

# setsid so the VM outlives the shell Hyprland dispatched us from, and keep the
# output -- discarding it is what hid a hard qemu startup failure for a week.
setsid quickemu --vm "$CONF" >"$LOG" 2>&1 &

# Pull the window to the workspace the key was pressed on once it maps.
for _ in $(seq 1 120); do
  addr=$(find_window)
  [ -n "$addr" ] && break
  sleep 0.5
done

if [ -n "$addr" ]; then
  focus_window "$addr"
else
  notify-send "Windows 11" "VM window never appeared: $(tail -1 "$LOG")" -t 8000
  exit 1
fi
