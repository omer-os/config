#!/usr/bin/env python3
"""Direct workspace switcher with sticky empty workspaces.

ALT+N goes straight to Hyprland workspace N -- there is no positional
remapping any more, so a gap in the workspace list can never shift what a
keybind targets. To keep the layout stable, workspaces 1..hi are marked
persistent (Hyprland won't destroy them when they go empty), where hi is the
highest workspace that still holds a window, or N, whichever is larger.

The effect the user asked for:
  * Emptying a *middle* workspace (e.g. 5 workspaces, clear #2) leaves it
    visible and empty instead of destroying it and pulling 3,4,5 back a slot.
  * Trailing empty workspaces above the last one in use are trimmed, so the
    list never grows without bound.

Usage:
    workspace.py focus <n>   -- go to workspace n
    workspace.py move  <n>   -- move the active window to workspace n (and follow)
    workspace.py close <n>   -- close every window on workspace n and drop it
"""

import json
import subprocess
import sys
import time


def hyprctl_json(*args):
    out = subprocess.run(
        ["hyprctl", "-j", *args], capture_output=True, text=True, timeout=2
    )
    return json.loads(out.stdout)


def close_workspace(n, clients, workspaces):
    """Close every window on workspace n, then let the workspace itself go."""
    for c in clients:
        if c.get("workspace", {}).get("id") == n:
            subprocess.run(
                ["hyprctl", "dispatch",
                 f"hl.dsp.window.close({{ window = 'address:{c['address']}' }})"],
                timeout=2,
            )

    # Drop the sticky rule so Hyprland can destroy it once it's empty.
    subprocess.run(
        ["hyprctl", "eval",
         f'hl.workspace_rule({{ workspace = "{n}", persistent = false }})'],
        timeout=2,
    )

    # An active workspace is never destroyed, so step off it onto the nearest
    # other workspace in use. Give apps a moment to actually close first.
    try:
        active = hyprctl_json("activeworkspace").get("id")
    except Exception:
        return
    if active != n:
        return
    time.sleep(0.3)
    others = [
        w.get("id", 0) for w in hyprctl_json("workspaces")
        if w.get("id", 0) >= 1 and w.get("id") != n
    ]
    if others:
        target = min(others, key=lambda w: (abs(w - n), w > n))
        subprocess.run(
            ["hyprctl", "dispatch", f"hl.dsp.focus({{ workspace = '{target}' }})"],
            timeout=2,
        )


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ("focus", "move", "close"):
        sys.exit("usage: workspace.py focus|move|close <n>")
    action = sys.argv[1]
    try:
        n = int(sys.argv[2])
    except ValueError:
        sys.exit("n must be an integer")
    if n < 1:
        sys.exit(0)

    try:
        clients = hyprctl_json("clients")
        workspaces = hyprctl_json("workspaces")
    except Exception:
        clients, workspaces = [], []

    if action == "close":
        close_workspace(n, clients, workspaces)
        return

    # Window count per regular workspace.
    counts = {}
    for c in clients:
        wid = c.get("workspace", {}).get("id", 0)
        if wid >= 1:
            counts[wid] = counts.get(wid, 0) + 1

    # Keep everything up to the last workspace in use (or the one we're heading
    # to) alive; nothing above it.
    max_used = max([w for w in counts] + [0])
    hi = max(max_used, n)

    existing = [w.get("id", 0) for w in workspaces]

    rules = [
        f'hl.workspace_rule({{ workspace = "{i}", persistent = true }})'
        for i in range(1, hi + 1)
    ]
    # Release any empty workspace stranded above hi so it can be reclaimed.
    for wid in existing:
        if wid > hi and counts.get(wid, 0) == 0:
            rules.append(
                f'hl.workspace_rule({{ workspace = "{wid}", persistent = false }})'
            )

    # This Hyprland build uses the non-legacy parser, so `hyprctl keyword` is
    # rejected -- workspace rules have to go through a Lua eval instead.
    subprocess.run(["hyprctl", "eval", "\n".join(rules)], timeout=2)

    # This build's dispatch takes a Lua expression, not the classic
    # "workspace <n>" args. The workspace id must be passed as a *string* --
    # a bare number silently no-ops (same reason the scroll binds use 'e+1').
    if action == "focus":
        expr = f"hl.dsp.focus({{ workspace = '{n}' }})"
    else:
        expr = f"hl.dsp.window.move({{ workspace = '{n}' }})"
    subprocess.run(["hyprctl", "dispatch", expr], timeout=2)


if __name__ == "__main__":
    main()
