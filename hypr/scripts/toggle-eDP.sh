#!/usr/bin/env bash
# Toggle the laptop screen (eDP-1) on/off via Hyprland's own monitor config.
# Using `hyprctl eval` (instead of wlr-randr) keeps the off-state in Hyprland's
# view, so other config evals (e.g. zen mode) don't re-enable the screen.
OUT="eDP-1"

disabled=$(hyprctl monitors all -j | jq -r --arg o "$OUT" '.[] | select(.name==$o) | .disabled')

if [ "$disabled" = "true" ]; then
  hyprctl eval "hl.monitor({ output = \"$OUT\", disabled = false, mode = \"preferred\", position = \"auto\", scale = \"auto\" })"
else
  hyprctl eval "hl.monitor({ output = \"$OUT\", disabled = true })"
fi
