#!/usr/bin/env bash
set -euo pipefail

MONITOR="eDP-1"
MODE_LOW="2880x1800@60"
MODE_HIGH="2880x1800@90"

get_hz() {
    hyprctl monitors -j | jq -r --arg m "$MONITOR" '.[] | select(.name==$m) | .refreshRate | floor'
}

case "${1:-status}" in
    status)
        hz=$(get_hz)
        echo "{\"text\": \"${hz}Hz\", \"tooltip\": \"eDP-1 @ ${hz}Hz (click to toggle 60/90Hz)\"}"
        ;;
    toggle)
        hz=$(get_hz)
        if [ "$hz" -ge 90 ]; then
            target="$MODE_LOW"
        else
            target="$MODE_HIGH"
        fi
        hyprctl eval "hl.monitor({output='${MONITOR}', mode='${target}', position='0x0', scale=2.0})" >/dev/null
        pkill -RTMIN+9 waybar || true
        ;;
esac
