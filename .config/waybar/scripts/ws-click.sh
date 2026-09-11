#!/usr/bin/env bash
# Click-to-switch workspace for Hyprland 0.55+ (Lua dispatcher)
# Hyprland broke the old "dispatch workspace N" IPC format.
# Waybar doesn't substitute {name} in on-click, so we determine
# the clicked workspace by mapping cursor X → button index.

CURSOR_X=$(hyprctl cursorpos -j | jq -r '.x | floor')

# Visible workspaces = those with clients + active workspace
ACTIVE=$(hyprctl activeworkspace -j | jq -r '.id')
CLIENTS_WS=$(hyprctl clients -j | jq -r '[.[].workspace.id] | unique | sort | .[]' 2>/dev/null)
VISIBLE_WS=$(printf '%s\n%s\n' "$CLIENTS_WS" "$ACTIVE" | grep -E '^[0-9]+$' | sort -n | uniq)

# CSS layout constants (style.css):
#   #workspaces { margin: 0 8px }
#   button { padding: 2px 12px; margin: 5px 2px; min-width: 18px }
#   → total per button = 2+12+18+12+2 = 46px
WIDGET_LEFT=8
BTN_PITCH=46

REL_X=$((CURSOR_X - WIDGET_LEFT))
[ "$REL_X" -lt 0 ] && exit 0

IDX=$((REL_X / BTN_PITCH))
WS_ID=$(echo "$VISIBLE_WS" | awk "NR==$((IDX + 1))")
[ -z "$WS_ID" ] && exit 0

hyprctl dispatch "hl.dsp.focus({workspace=\"$WS_ID\"})"
