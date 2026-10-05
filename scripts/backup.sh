#!/usr/bin/env bash
#
# backup: restic backup to SSD and/or HDD (whichever is mounted), then sync to ProtonDrive.

set -uo pipefail

export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
export RCLONE_CONFIG_PASS="$(cat /run/agenix/rclone-password)"

SSD_MOUNT="/mnt/ssd"
HDD_MOUNT="/mnt/hdd"
SSD_REPO="${SSD_MOUNT}/backups/restic_repo"
HDD_REPO="${HDD_MOUNT}/backups/restic_repo"

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

restic_backup() {
    local repo="$1"
    [[ -f "$repo/config" ]] || restic -r "$repo" init || return 1
    restic -r "$repo" backup --verbose \
        --exclude "$HOME/.cache" \
        --exclude "$HOME/.nix-profile" \
        --exclude "$HOME/.nix-defexpr" \
        --exclude "$HOME/.npm" \
        --exclude "$HOME/.var" \
        --exclude "$HOME/.mozilla" \
        --exclude "$HOME/.config/mozilla" \
        --exclude "$HOME/.config/vesktop" \
        --exclude "$HOME/.config/google-chrome" \
        --exclude "$HOME/.config/discord" \
        --exclude "$HOME/.config/Code" \
        --exclude "$HOME/.config/libreoffice" \
        --exclude "$HOME/.config/.venv" \
        --exclude "$HOME/.local/share/Trash" \
        --exclude "$HOME/.local/share/baloo" \
        --exclude "$HOME/.local/share/nvim" \
        --exclude "$HOME/.claude/file-history" \
        --exclude "$HOME/.claude/paste-cache" \
        --exclude "$HOME/.zcompdump*" \
        --exclude "$HOME/.Copy (1) config" \
        --exclude "**/.venv/" \
        --exclude "*.lock" \
        "$HOME"
    local backup_rc=$?

    restic -r "$repo" forget --keep-last 50 --prune
    local prune_rc=$?

    (( backup_rc == 0 && prune_rc == 0 ))
}

sync_protondrive() {
    rclone copy "$HOME/Documents/" pdrive:backup/documents \
        --protondrive-replace-existing-draft=true -P
}

ran_any_restic=0

if mountpoint -q "$SSD_MOUNT"; then
    ran_any_restic=1
    run_step "restic backup to $SSD_REPO" restic_backup "$SSD_REPO"
else
    echo "==> SSD not mounted at $SSD_MOUNT, skipping SSD backup." >&2
fi

if mountpoint -q "$HDD_MOUNT"; then
    ran_any_restic=1
    run_step "restic backup to $HDD_REPO" restic_backup "$HDD_REPO"
else
    echo "==> HDD not mounted at $HDD_MOUNT, skipping HDD backup." >&2
fi

if (( ! ran_any_restic )); then
    echo "==> Neither SSD nor HDD mounted, no restic backup performed." >&2
    failed+=("restic backup (no disks mounted)")
fi

run_step "ProtonDrive sync" sync_protondrive

if (( ${#failed[@]} )); then
    echo "==> Backup finished with failures: ${failed[*]}" >&2
    exit 1
fi

echo "==> Backup done."
