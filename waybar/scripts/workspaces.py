#!/usr/bin/env python3
"""Waybar workspace module: shows live window titles instead of numbers.

Only workspaces that actually exist are rendered (plus the active one, even
when empty). Each entry is the title of that workspace's most recently focused
window, cleaned up and truncated. Driven by Hyprland's event socket, so it
updates the instant something changes -- no polling.
"""

import json
import os
import re
import socket
import subprocess
import sys
from html import escape

# ── palette (keep in sync with style.css) ────────────────────────────────
ACTIVE_FG = "#050a05"
ACTIVE_BG = "#00ff5f"
IDLE_FG = "#35c95a"
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


def render():
    clients = hyprctl("clients")
    active = hyprctl("activeworkspace")
    workspaces = hyprctl("workspaces")
    if clients is None or active is None or workspaces is None:
        return None

    active_id = active.get("id", 1)

    # Best (most recently focused) client per workspace. focusHistoryID 0 is
    # the currently focused window, so lower wins.
    best = {}
    counts = {}
    for c in clients:
        wid = c.get("workspace", {}).get("id")
        if wid is None or wid < 1:  # skip special workspaces
            continue
        counts[wid] = counts.get(wid, 0) + 1
        prev = best.get(wid)
        if prev is None or c.get("focusHistoryID", 999) < prev.get("focusHistoryID", 999):
            best[wid] = c

    # Every workspace Hyprland says exists, plus safety nets for the active
    # one and any workspace that still has clients. Persistent empty
    # workspaces show up here too, so a cleared middle workspace stays put.
    existing = {w["id"] for w in workspaces if w.get("id", 0) >= 1}
    ids = sorted(existing | set(counts) | {active_id})

    parts = []
    for wid in ids:
        client = best.get(wid)
        if client:
            label = clean_title(client.get("title"), client.get("class"))
        else:
            label = "empty"

        # FSI/PDI-isolate the title so RTL text (Arabic, Hebrew) can't
        # bidi-reorder the position number, the +N counter, or neighbours.
        label = "\u2068" + escape(label) + "\u2069"
        if client:
            extra = counts.get(wid, 1) - 1
            if extra:
                label += f" +{extra}"
        # Both states must render the exact same characters -- " {wid} {label} "
        # -- so activating a workspace only changes colour and never shifts the
        # row sideways. The number shown is the real Hyprland workspace ID,
        # which is exactly what ALT+N now targets.
        if wid == active_id:
            parts.append(
                f"<span background='{ACTIVE_BG}' foreground='{ACTIVE_FG}'>"
                f" {wid} {label} </span>"
            )
        else:
            parts.append(
                f"<span foreground='{IDLE_IDX}'> {wid} </span>"
                f"<span foreground='{IDLE_FG}'>{label}</span>"
                f"<span> </span>"
            )

    # Leading LRM pins the paragraph base direction to LTR; otherwise Pango
    # infers it from the first strong character, so an Arabic title in the
    # first slot would lay the whole row out right-to-left.
    return {"text": "\u200e" + "".join(parts), "tooltip": ""}


def emit():
    data = render()
    if data:
        print(json.dumps(data), flush=True)


def main():
    emit()

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
        emit()


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, BrokenPipeError):
        sys.exit(0)
