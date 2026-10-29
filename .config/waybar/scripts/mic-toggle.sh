#!/usr/bin/env bash
set -euo pipefail

# mic mute/unmute toggle for waybar, next to the volume module

status() {
    if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
        echo '{"text": "󰍭", "class": "muted", "tooltip": "mic muted (click to unmute)"}'
    else
        echo '{"text": "󰍬", "class": "unmuted", "tooltip": "mic unmuted (click to mute)"}'
    fi
}

case "${1:-status}" in
    status) status ;;
    toggle)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        pkill -RTMIN+10 waybar || true
        ;;
esac
