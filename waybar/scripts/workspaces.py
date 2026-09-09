#!/usr/bin/env python3
"""Waybar workspace slot: one module per workspace, so each is clickable.

Waybar can only attach a single click handler to a module, so the row is built
from ten independent modules (custom/ws1 .. custom/ws10) rather than one
pre-rendered string. Each instance of this script owns one slot:

    workspaces.py <n>

and prints the title of workspace n's most recently focused window. A slot
whose workspace does not exist prints empty text, which waybar renders as a
hidden module -- so the row still collapses to only the workspaces in use.

Driven by Hyprland's event socket, so it updates the instant something
changes -- no polling.
"""

import json
import os
import re
import socket
import subprocess
import sys
from html import escape

# ── palette (keep in sync with style.css) ────────────────────────────────
IDLE_IDX = "#1c6b33"

MAX_TITLE = 22

# Suffixes apps tack onto every window title. Longest first so " - Google
# Chrome" wins over " - Chrome".
SUFFIXES = [
    " - Google Chrome",
    " — Google Chrome",
    " - Chromium",
    " - Mozilla Firefox",
    " — Mozilla Firefox",
    " - Zen Browser",
    " - Visual Studio Code",
    " - Code - OSS",
    " - VSCodium",
    " - Brave",
    " - Thunar",
    " - Dolphin",
]

# Fallbacks when a window has no usable title.
CLASS_NAMES = {
    "google-chrome": "Chrome",
    "chromium": "Chromium",
    "firefox": "Firefox",
    "zen": "Zen",
    "kitty": "Terminal",
    "code": "Code",
    "dolphin": "Files",
    "thunar": "Files",
    "org.pwmt.zathura": "Zathura",
    "spotify": "Spotify",
    "discord": "Discord",
}


def hyprctl(*args):
    try:
        out = subprocess.run(
            ["hyprctl", "-j", *args], capture_output=True, text=True, timeout=2
        )
        return json.loads(out.stdout)
    except Exception:
        return None


def pretty_class(cls):
    if not cls:
        return "?"
    key = cls.lower()
    if key in CLASS_NAMES:
        return CLASS_NAMES[key]
    # org.kde.dolphin -> Dolphin
    return cls.rsplit(".", 1)[-1].capitalize()


def clean_title(title, cls):
    title = (title or "").strip()
    for suffix in SUFFIXES:
        if title.endswith(suffix):
            title = title[: -len(suffix)].strip()
            break
    # Strip leading spinner/status junk some TUIs prepend.
    title = re.sub(r"^[\W_]+", "", title).strip()
    if not title:
        return pretty_class(cls)
    if len(title) > MAX_TITLE:
        title = title[: MAX_TITLE - 1].rstrip() + "…"
    return title


def render(slot):
    clients = hyprctl("clients")
    active = hyprctl("activeworkspace")
    workspaces = hyprctl("workspaces")
    if clients is None or active is None or workspaces is None:
        return None

    active_id = active.get("id", 1)

    mine = [
        c for c in clients if c.get("workspace", {}).get("id") == slot
    ]
    existing = {w["id"] for w in workspaces if w.get("id", 0) >= 1}

    # Nothing here and Hyprland doesn't know about it: hide the slot. The
    # active workspace always renders, even when empty.
    if slot not in existing and not mine and slot != active_id:
        return {"text": "", "tooltip": "", "class": "hidden"}

    # Most recently focused client wins; focusHistoryID 0 is the focused one.
    best = None
    for c in mine:
        if best is None or c.get("focusHistoryID", 999) < best.get("focusHistoryID", 999):
            best = c

    if best:
        label = clean_title(best.get("title"), best.get("class"))
        tooltip = "\n".join(
            escape(clean_title(c.get("title"), c.get("class"))) for c in mine
        )
    else:
        label = "empty"
        tooltip = f"workspace {slot} · empty"

    # FSI/PDI-isolate the title so RTL text (Arabic, Hebrew) can't
    # bidi-reorder the position number, the +N counter, or neighbours.
    body = "⁨" + escape(label) + "⁩"
    extra = len(mine) - 1
    if extra > 0:
        body += f" +{extra}"

    is_active = slot == active_id
    # Both states render the exact same characters, so activating a workspace
    # only changes colour and never shifts the row sideways. The number shown
    # is the real Hyprland workspace ID -- exactly what ALT+N targets.
    if is_active:
        text = f"{slot} {body}"
    else:
        text = f"<span foreground='{IDLE_IDX}'>{slot}</span> {body}"

    # Leading LRM pins the paragraph base direction to LTR; otherwise Pango
    # infers it from the first strong character, so an Arabic title would lay
    # the whole slot out right-to-left.
    return {
        "text": "‎" + text,
        "tooltip": tooltip,
        "class": "active" if is_active else ("occupied" if best else "empty"),
    }


def emit(slot):
    data = render(slot)
    if data:
        print(json.dumps(data), flush=True)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: workspaces.py <workspace-number>")
    slot = int(sys.argv[1])

    emit(slot)

    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    if not sig:
        return
    path = f"{runtime}/hypr/{sig}/.socket2.sock"

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(path)

    buf = b""
    while True:
        # Coalesce bursts of events (opening a window fires several) into a
        # single redraw.
        sock.settimeout(None)
        chunk = sock.recv(4096)
        if not chunk:
            break
        buf += chunk
        sock.settimeout(0.04)
        while True:
            try:
                more = sock.recv(4096)
            except socket.timeout:
                break
            if not more:
                break
            buf += more
        buf = buf.rsplit(b"\n", 1)[-1] if b"\n" in buf else b""
        emit(slot)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
