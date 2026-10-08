#!/usr/bin/env bash
# Wallpaper picker for ~/.config/hypr/wallpapers (drawn by awww).
#   wallpaper.sh            re-apply the saved choice (used at login)
#   wallpaper.sh next|prev  cycle through the folder
#   wallpaper.sh <name>     set a file from the folder (or any path)
#   wallpaper.sh list       show what's in the folder
dir="$HOME/.config/hypr/wallpapers"
state="$dir/.current"

pgrep -x awww-daemon >/dev/null || { awww-daemon & sleep 0.3; }

mapfile -t walls < <(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) | sort)
current=$(cat "$state" 2>/dev/null)

pick() {
	local step=$1 i
	for i in "${!walls[@]}"; do
		[[ ${walls[$i]} == "$current" ]] && { echo "${walls[$(((i + step + ${#walls[@]}) % ${#walls[@]}))]}"; return; }
	done
	echo "${walls[0]}"
}

case "$1" in
	"") target=${current:-${walls[0]}} ;;
	next) target=$(pick 1) ;;
	prev) target=$(pick -1) ;;
	list) printf '%s\n' "${walls[@]##*/}"; exit ;;
	*) [[ -f $1 ]] && target=$(realpath "$1") || target="$dir/$1" ;;
esac

[[ -f $target ]] || { echo "no wallpaper: $target" >&2; exit 1; }
awww img "$target" --transition-type fade --transition-duration 0.6 && echo "$target" >"$state"
echo "${target##*/}"
