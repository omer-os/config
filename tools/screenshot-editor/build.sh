#!/usr/bin/env bash
# Builds the screenshot editor that ALT+S / ALT+SHIFT+S open: upstream swappy
# with floating-toolbar.patch on top, installed as ~/.local/bin/swappy-mini.
#
# The patch does three things the packaged swappy cannot be configured into:
#   * one floating toolbar over the image, instead of a side panel and a
#     header bar that between them ate a third of the window
#   * Enter saves and quits (upstream only binds Ctrl+S)
#   * a fullscreen shot opens at two thirds of the screen, not three quarters
#
# Re-run it after editing the patch, or to move to a newer upstream: bump
# COMMIT, run, and fix the patch if it no longer applies. The distro package
# can stay installed; nothing here touches it.

set -euo pipefail

REPO=https://github.com/jtheoof/swappy.git
COMMIT=ff7d641b8c0d461b8a90448a5893e4aa3a0533b1 # master, 2025-08-29 (v1.8.0)

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
patch_file="$here/floating-toolbar.patch"
src="${XDG_CACHE_HOME:-$HOME/.cache}/swappy-mini"
dest="$HOME/.local/bin/swappy-mini"

for tool in git meson ninja cc pkg-config; do
	command -v "$tool" >/dev/null && continue
	echo "missing build dependency: $tool" >&2
	exit 1
done

if [[ ! -d $src/.git ]]; then
	rm -rf "$src"
	git clone --quiet "$REPO" "$src"
fi

git -C "$src" fetch --quiet origin "$COMMIT" 2>/dev/null || git -C "$src" fetch --quiet
# Checkout is deliberately destructive: the tree is a build artefact, and the
# only edits worth keeping live in the patch next to this script.
git -C "$src" checkout --quiet --force "$COMMIT"
git -C "$src" clean -qfd
git -C "$src" apply "$patch_file"

meson setup "$src/build" "$src" --buildtype=release --wipe >/dev/null
ninja -C "$src/build" >/dev/null

mkdir -p "$(dirname "$dest")"
install -m755 "$src/build/swappy" "$dest"
echo "installed $dest"
