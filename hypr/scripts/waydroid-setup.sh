#!/usr/bin/env bash
# One-time root setup for Waydroid: firewall holes + adb config.
# Run with: sudo ~/.config/hypr/scripts/waydroid-setup.sh
#
# Safe to re-run -- every change checks its current state first, and the two
# Waydroid config files are backed up to *.bak before the first edit.
#
# What this fixes, and why it needs root:
#
#   1. ufw runs with INPUT and FORWARD both defaulting to DROP and no user
#      rules at all. Waydroid installs its own permissive rules, but into a
#      separate nftables table (inet lxc / ip lxc). nftables evaluates every
#      base chain on a hook, so a DROP from ufw's chains vetoes Waydroid's
#      ACCEPT. The result: Android's DHCPDISCOVER never reaches the dnsmasq on
#      waydroid0, so it never gets a lease, never gets a default route or DNS,
#      and every connection fails with "Network is unreachable". ICMP still
#      worked, which is what made this look like a half-working network --
#      ufw's before.rules accepts echo-request specifically.
#
#   2. That same missing lease is why "waydroid status" printed
#      "IP address: UNKNOWN": Waydroid reads the container IP out of the
#      dnsmasq lease file, so auto_adb could not have worked even if enabled.
#
# NAT is deliberately not touched -- waydroid-net.sh already installs the
# masquerade rule, and it was never the problem.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This script needs root: sudo $0" >&2
  exit 1
fi

CFG=/var/lib/waydroid/waydroid.cfg
PROP=/var/lib/waydroid/waydroid_base.prop

changed=0

note() { printf '  %s\n' "$1"; }

# --- 1. Firewall -------------------------------------------------------------
# Two targeted rules on the waydroid0 bridge only. The global DROP policies stay
# as they are, so docker's bridges and anything reachable from the LAN are
# completely unaffected.
#
# "allow in" covers DHCP (udp/67) and DNS (tcp+udp/53) so the lease and resolver
# work, and also lets Android reach dev servers running on the host at
# 192.168.240.1 -- hitting a local Next.js/API from the emulator is the whole
# point of developing against it.
#
# "route allow in" is the FORWARD half: Android -> waydroid0 -> wlan0 -> internet.
# Return traffic is already covered by the RELATED,ESTABLISHED accept that ufw
# puts in ufw-before-forward.

echo "Firewall (ufw):"

if ! command -v ufw >/dev/null; then
  note "ufw not installed -- nothing to do"
elif ! ufw status 2>/dev/null | grep -qx "Status: active"; then
  note "ufw is installed but inactive -- leaving it alone"
else
  # ufw itself skips exact duplicates, but it compares the comment too, so an
  # existing rule added by hand without one would end up duplicated. Check first.
  if ufw status | grep -qE '^Anywhere on waydroid0[[:space:]]+ALLOW IN'; then
    note "input rule already present"
  else
    ufw allow in on waydroid0 comment 'waydroid: DHCP/DNS + host dev servers' >/dev/null
    note "added: allow in on waydroid0"
    changed=1
  fi

  if ufw status | grep -qE 'ALLOW FWD.*on waydroid0'; then
    note "forward rule already present"
  else
    ufw route allow in on waydroid0 comment 'waydroid: Android -> internet' >/dev/null
    note "added: route allow in on waydroid0"
    changed=1
  fi
fi

# --- 2. Waydroid config ------------------------------------------------------
# auto_adb makes Waydroid run "adb connect <ip>" itself once Android finishes
# booting. Waydroid's upgrader turns this off by default, but only because
# ro.adb.secure=1 would make every session pop an RSA authorisation dialog --
# which the next step removes.

echo "Waydroid config:"

backup_once() {
  [ -f "$1.bak" ] || cp -a "$1" "$1.bak"
}

if [ ! -f "$CFG" ]; then
  note "$CFG missing -- is Waydroid initialised?"
elif grep -qE '^auto_adb\s*=\s*True' "$CFG"; then
  note "auto_adb already True"
else
  backup_once "$CFG"
  sed -i -E 's/^(auto_adb\s*=\s*).*/\1True/' "$CFG"
  note "auto_adb = True"
  changed=1
fi

# --- 3. Waydroid props -------------------------------------------------------
# ro.adb.secure=0 drops the per-session "Allow USB debugging?" RSA prompt, which
# is the thing that made the device intermittently invisible to Android Studio.
# ro.debuggable=1 additionally allows "adb root".
#
# ro.hardware.egl is deliberately left alone. The file says swiftshader, but
# Waydroid overrides it at session start -- the running value is "angle", i.e.
# ANGLE on top of the NVIDIA Vulkan driver. That already works; changing it
# would be a downgrade to software rendering.
#
# waydroid.prop is regenerated from this file on every session start, so editing
# the base file here is enough.

echo "Waydroid props:"

set_prop() {
  local key=$1 want=$2
  if grep -qE "^${key}=${want}$" "$PROP"; then
    note "${key}=${want} already set"
  elif grep -qE "^${key}=" "$PROP"; then
    backup_once "$PROP"
    sed -i -E "s/^(${key}=).*/\1${want}/" "$PROP"
    note "${key}=${want}"
    changed=1
  else
    backup_once "$PROP"
    printf '%s=%s\n' "$key" "$want" >>"$PROP"
    note "${key}=${want} (appended)"
    changed=1
  fi
}

if [ ! -f "$PROP" ]; then
  note "$PROP missing -- is Waydroid initialised?"
else
  set_prop 'ro\.adb\.secure' 0
  set_prop 'ro\.debuggable' 1
fi

# -----------------------------------------------------------------------------

echo
if [ "$changed" -eq 0 ]; then
  echo "Nothing to change -- already set up."
else
  echo "Done. Restart the session for it to take effect:"
  echo "    waydroid session stop && ~/.config/hypr/scripts/waydroid.sh"
  echo
  echo "Then confirm DHCP is working (this file was empty before):"
  echo "    cat /var/lib/misc/dnsmasq.waydroid0.leases"
fi
