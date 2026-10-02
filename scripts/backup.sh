#!/usr/bin/env bash
#
# backup: restic backup to local SSD, then sync to ProtonDrive and Google Drive.

set -uo pipefail

export RESTIC_PASSWORD_FILE=/run/agenix/restic-password
export RCLONE_CONFIG_PASS="$(cat /run/agenix/rclone-password)"

SSD_MOUNT="/mnt/ssd/"
RESTIC_REPO="${SSD_MOUNT}backups/restic_repo"

mountpoint -q "$SSD_MOUNT" || { echo "SSD not mounted at $SSD_MOUNT" >&2; exit 1; }

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
    [[ -f "$RESTIC_REPO/config" ]] || restic -r "$RESTIC_REPO" init || return 1
    restic -r "$RESTIC_REPO" backup --verbose \
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

    restic -r "$RESTIC_REPO" forget --keep-last 50 --prune
    local prune_rc=$?

    (( backup_rc == 0 && prune_rc == 0 ))
}

sync_protondrive() {
    rclone copy "$HOME/Documents/" pdrive:backup/documents \
        --protondrive-replace-existing-draft=true -P
}

sync_googledrive() {
    rclone copy "$RESTIC_REPO" gdrive:restic_repo \
        --progress --transfers 4 --checkers 8 \
        --retries 10 --low-level-retries 20 \
        --timeout 5m --contimeout 1m --stats 5s
}

run_step "restic backup to $RESTIC_REPO" restic_backup
run_step "ProtonDrive sync" sync_protondrive
run_step "Google Drive sync" sync_googledrive

if (( ${#failed[@]} )); then
    echo "==> Backup finished with failures: ${failed[*]}" >&2
    exit 1
fi

echo "==> Backup done."
