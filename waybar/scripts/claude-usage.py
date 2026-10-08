#!/usr/bin/env python3
"""Waybar module: Claude subscription usage.

Reads the OAuth token Claude Code already stores locally and asks
/api/oauth/usage how much of the current rate-limit windows is spent.
The token never leaves this process; only percentages are printed.
"""

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

CREDS = os.path.expanduser("~/.claude/.credentials.json")
CACHE = os.path.expanduser("~/.cache/waybar-claude-usage.json")
CACHE_TTL = 90  # seconds; the windows move slowly, don't hammer the API
URL = "https://api.anthropic.com/api/oauth/usage"

# Windows we render, in tooltip order.
WINDOWS = [
    ("five_hour", "session"),
    ("seven_day", "week"),
    ("seven_day_opus", "opus"),
    ("seven_day_sonnet", "sonnet"),
]


def find_token(obj):
    """Pull accessToken out of the credentials blob, whatever it's nested in."""
    if isinstance(obj, dict):
        tok = obj.get("accessToken")
        if isinstance(tok, str) and tok:
            return tok
        for v in obj.values():
            tok = find_token(v)
            if tok:
                return tok
    return None


def token():
    try:
        with open(CREDS) as fh:
            return find_token(json.load(fh))
    except (OSError, ValueError):
        pass
    # Fall back to a keyring-backed install (macOS, or Linux with a helper).
    for cmd in (["security", "find-generic-password", "-s", "Claude Code-credentials", "-w"],):
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
            if out.returncode == 0:
                return find_token(json.loads(out.stdout))
        except (OSError, ValueError, subprocess.SubprocessError):
            continue
    return None


def fetch():
    tok = token()
    if not tok:
        return None
    req = urllib.request.Request(
        URL,
        headers={
            "Authorization": f"Bearer {tok}",
            "Content-Type": "application/json",
            "anthropic-beta": "oauth-2025-04-20",
            "User-Agent": "waybar-claude-usage",
        },
    )
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.load(resp)


def cached():
    """Fetch, but reuse a recent answer and fall back to a stale one on error."""
    try:
        with open(CACHE) as fh:
            blob = json.load(fh)
        if time.time() - blob["at"] < CACHE_TTL:
            return blob["data"], False
    except (OSError, ValueError, KeyError):
        blob = None

    try:
        data = fetch()
    except (urllib.error.URLError, OSError, ValueError):
        data = None

    if data is None:
        if blob:
            return blob["data"], True
        return None, True

    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    tmp = CACHE + ".tmp"
    with open(tmp, "w") as fh:
        json.dump({"at": time.time(), "data": data}, fh)
    os.replace(tmp, CACHE)
    return data, False


def pct(window):
    """The endpoint reports utilization already on a 0-100 scale."""
    if not isinstance(window, dict):
        return None
    u = window.get("utilization")
    if u is None:
        return None
    return round(u)


def resets_in(window):
    if not isinstance(window, dict):
        return ""
    at = window.get("resets_at") or window.get("resetsAt")
    if at is None:
        return ""
    if isinstance(at, str):
        try:
            import datetime

            at = datetime.datetime.fromisoformat(at.replace("Z", "+00:00")).timestamp()
        except ValueError:
            return ""
    left = int(at - time.time())
    if left <= 0:
        return "now"
    if left < 3600:
        return f"{left // 60}m"
    if left < 86400:
        return f"{left // 3600}h {left % 3600 // 60}m"
    return f"{left // 86400}d {left % 86400 // 3600}h"


def scoped_limits(data):
    """Per-model weekly windows, which the API only reports in `limits`."""
    out = []
    for lim in data.get("limits") or []:
        if not isinstance(lim, dict):
            continue
        model = ((lim.get("scope") or {}).get("model") or {})
        name = model.get("display_name")
        p = lim.get("percent")
        if not name or p is None:
            continue
        out.append({"label": name.lower(), "pct": round(p), "resets_at": lim.get("resets_at")})
    return out


BAR_CELLS = 12
COL_TEXT = "#ededf0"
COL_SUB = "#a8a8b0"
COL_MUTED = "#5c5c66"
COL_WARN = "#e0b341"
COL_CRIT = "#ff5f57"


def colour_for(p):
    if p >= 90:
        return COL_CRIT
    if p >= 70:
        return COL_WARN
    return COL_SUB


def bar(p):
    """A filled/empty block gauge, tinted by how close the window is to full."""
    filled = min(BAR_CELLS, max(0, round(p / 100 * BAR_CELLS)))
    if p > 0:
        filled = max(filled, 1)
    return (
        f"<span foreground='{colour_for(p)}'>{'\u2588' * filled}</span>"
        f"<span foreground='{COL_MUTED}'>{'\u2500' * (BAR_CELLS - filled)}</span>"
    )


def row(label, p, left):
    tail = f"  <span foreground='{COL_MUTED}'>{left} left</span>" if left else ""
    return (
        f"<span foreground='{COL_MUTED}'>{label:<8}</span>"
        f"{bar(p)}"
        f"  <span foreground='{colour_for(p)}'>{p:>3}%</span>{tail}"
    )


def out(text, tooltip, css=""):
    print(json.dumps({"text": text, "tooltip": tooltip, "class": css}))


def unavailable(reason):
    out(
        "--",
        f"<span foreground='{COL_TEXT}'><b>Claude usage</b></span>\n"
        f"<span foreground='{COL_MUTED}'>{reason}</span>",
        "off",
    )


def refresh():
    """Click handler: drop the cache and nudge waybar to re-run us."""
    try:
        os.remove(CACHE)
    except OSError:
        pass
    subprocess.run(["pkill", "-RTMIN+9", "waybar"], check=False)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "refresh":
        refresh()
        return

    data, stale = cached()
    if not data:
        unavailable("unavailable \u2014 run `claude` and sign in")
        return

    rows = []
    seen = set()
    top = 0
    for key, label in WINDOWS:
        p = pct(data.get(key))
        if p is None:
            continue
        seen.add(label)
        rows.append(row(label, p, resets_in(data.get(key))))
        if key in ("five_hour", "seven_day"):
            top = max(top, p)

    # Per-model weekly windows (Fable, Opus, ...) only show up in `limits`.
    for lim in scoped_limits(data):
        if lim["label"] in seen:
            continue
        seen.add(lim["label"])
        rows.append(row(lim["label"], lim["pct"], resets_in(lim)))

    if not rows:
        unavailable("no window data")
        return

    extra = data.get("extra_usage") or {}
    if extra.get("is_enabled") and extra.get("used_credits") is not None:
        cur = extra.get("currency") or "USD"
        rows.append(
            f"<span foreground='{COL_MUTED}'>{'extra':<8}</span>"
            f"<span foreground='{COL_SUB}'>{extra['used_credits']:.2f} {cur}</span>"
        )

    session = pct(data.get("five_hour"))
    text = f"{session if session is not None else top}%"

    tooltip = f"<span foreground='{COL_TEXT}'><b>Claude usage</b></span>\n\n" + "\n".join(rows)
    if stale:
        tooltip += f"\n\n<span foreground='{COL_MUTED}'>cached \u2014 API unreachable</span>"

    css = "ok"
    if top >= 90:
        css = "critical"
    elif top >= 70:
        css = "warning"
    if stale:
        css += " stale"

    out(text, tooltip, css)


if __name__ == "__main__":
    main()
