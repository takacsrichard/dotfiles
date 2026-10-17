#!/usr/bin/env bash
# Toggle waybar between position "top" and "bottom", then restart it to apply.
set -euo pipefail

config="$HOME/.config/waybar/config.jsonc"

if grep -q '"position": *"top"' "$config"; then
    sed -i 's/"position": *"top"/"position": "bottom"/' "$config"
    newpos="bottom"
else
    sed -i 's/"position": *"bottom"/"position": "top"/' "$config"
    newpos="top"
fi

pkill waybar || true
waybar &
disown

notify-send "Waybar" "Moved to $newpos" -a "Hyprland"
