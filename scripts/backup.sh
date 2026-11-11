#!/usr/bin/env bash
#
# backup: sync Documents/uni/life to ProtonDrive.

set -uo pipefail

export RCLONE_CONFIG_PASS="$(cat /run/agenix/rclone-password)"

failed=()

run_step() {
    local name="$1"; shift
    echo "==> $name..."
    if "$@"; then
        echo "==> $name done."
    else
        echo "==> $name FAILED." >&2
        failed+=("$name")
    fi
}

sync_protondrive() {
    local src="$1" dest="$2"
    rclone copy "$src" "pdrive:$dest" \
        --protondrive-replace-existing-draft=true -P
}

run_step "ProtonDrive sync (documents)" sync_protondrive "$HOME/Documents/" "backup/documents"
run_step "ProtonDrive sync (uni)" sync_protondrive "$HOME/uni/" "backup/uni"
run_step "ProtonDrive sync (life)" sync_protondrive "$HOME/life/" "backup/life"

if (( ${#failed[@]} )); then
    echo "==> Backup finished with failures: ${failed[*]}" >&2
    exit 1
fi

echo "==> Backup done."
