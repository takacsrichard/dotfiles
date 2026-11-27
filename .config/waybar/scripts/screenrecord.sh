#!/usr/bin/env bash
set -euo pipefail

# screen recording toggle for waybar, wf-recorder based

PIDFILE="/tmp/wf-recorder.pid"
OUTDIR="$HOME/Videos"

status() {
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo '{"text": "󰑊", "class": "recording", "tooltip": "recording... (click to stop)"}'
    else
        echo '{"text": "󰻃", "class": "idle", "tooltip": "left-click: record screen\nright-click: record region"}'
    fi
}

stop() {
    if [ -f "$PIDFILE" ]; then
        kill -INT "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi
}

start() {
    mkdir -p "$OUTDIR"
    local out="$OUTDIR/recording-$(date +%Y%m%d-%H%M%S).mp4"
    local mon
    mon=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
    if [ -n "${1:-}" ]; then
        local geom
        geom=$(slurp) || return 0
        wf-recorder -g "$geom" -f "$out" &
    else
        wf-recorder -o "$mon" -f "$out" &
    fi
    echo $! > "$PIDFILE"
}

case "${1:-status}" in
    status) status ;;
    toggle)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            stop
        else
            start "${2:-}"
        fi
        pkill -RTMIN+11 waybar || true
        ;;
esac
