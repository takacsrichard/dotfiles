#!/usr/bin/env bash
#
# backup: restic backup to local SSD, then sync to ProtonDrive and Google Drive.

set -euo pipefail

SSD_MOUNT="/mnt/ssd/"
RESTIC_REPO="${SSD_MOUNT}backups/restic_repo"

mountpoint -q "$SSD_MOUNT" || { echo "SSD not mounted at $SSD_MOUNT" >&2; exit 1; }

[[ -f "$RESTIC_REPO/config" ]] || restic -r "$RESTIC_REPO" init

echo "==> Backing up to $RESTIC_REPO..."
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

# todo: backup or putzfrau?
echo "==> Pruning old snapshots..."
restic -r "$RESTIC_REPO" forget --keep-last 50 --prune

echo "==> Syncing to ProtonDrive..."
rclone copy "$HOME/Documents/" pdrive:backup/documents \
    --protondrive-replace-existing-draft=true -P

echo "==> Syncing restic repo to GoogleDrive..."
rclone copy "$RESTIC_REPO" gdrive:restic_repo \
    --progress --transfers 4 --checkers 8 \
    --retries 10 --low-level-retries 20 \
    --timeout 5m --contimeout 1m --stats 5s

echo "==> Backup done."
