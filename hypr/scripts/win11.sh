#!/usr/bin/env bash
# Launch or focus the Windows 11 VM (quickemu/KVM).
# Bound to ALT+SHIFT+W. If the VM window is already open anywhere,
# it gets pulled to the current workspace and focused; otherwise the
# VM is booted and its window opens in the current workspace.

VM_DIR="$HOME/VMs"
CONF="windows-11.conf"

# VM viewer window already open? Bring it here and focus it.
addr=$(hyprctl clients -j | jq -r \
  '.[] | select((.class + .title) | test("spicy|spice|windows-11|qemu"; "i")) | .address' | head -1)
if [ -n "$addr" ]; then
  hyprctl dispatch movetoworkspace "$(hyprctl activeworkspace -j | jq '.id'),address:$addr"
  hyprctl dispatch focuswindow "address:$addr"
  exit 0
fi

if ! command -v quickemu >/dev/null; then
  notify-send "Windows 11" "quickemu is not installed (paru -S quickemu)" -t 4000
  exit 1
fi

if [ ! -f "$VM_DIR/$CONF" ]; then
  notify-send "Windows 11" "VM not set up yet: cd ~/VMs && quickget windows-11" -t 4000
  exit 1
fi

notify-send "Windows 11" "Booting VM..." -t 2000
cd "$VM_DIR" || exit 1
quickemu --vm "$CONF" >/dev/null 2>&1 &
