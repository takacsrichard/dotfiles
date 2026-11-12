#!/usr/bin/env bash
#
# backup-disk: restic backup to a single external disk. takes the mount
# point as $1, triggered when that disk gets mounted (see backup.nix).

set -uo pipefail

export RESTIC_PASSWORD_FILE=/run/agenix/restic-password

mount_point="$1"
repo="$mount_point/backups/restic_repo"
label="$(basename "$mount_point")"

# guard against two restic runs racing the same (exfat, no posix locks) repo
exec 9>"/tmp/backup-${label}.lock"
flock -n 9 || {
  echo "==> backup to $mount_point already running, skipping."
  exit 0
}

[[ -f "$repo/config" ]] || restic -r "$repo" init

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
  --exclude "$HOME/.config/rclone" \
  --exclude "$HOME/.local/share/Trash" \
  --exclude "$HOME/.local/share/baloo" \
  --exclude "$HOME/.local/share/nvim" \
  --exclude "$HOME/.claude/file-history" \
  --exclude "$HOME/.claude/paste-cache" \
  --exclude "$HOME/.zcompdump*" \
  --exclude "$HOME/.Copy (1) config" \
  --exclude "*.venv*" \
  --exclude "*.lock" \
  "$HOME"
backup_rc=$?

restic -r "$repo" forget --keep-last 50 --prune
prune_rc=$?

if ((backup_rc == 0 && prune_rc == 0)); then
  echo "==> restic backup to $repo done."
else
  echo "==> restic backup to $repo FAILED." >&2
  exit 1
fi
