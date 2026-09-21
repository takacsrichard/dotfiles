set shell := ["zsh", "-euo", "pipefail", "-c"]

SSD_MOUNT := "/mnt/ssd/"
HDD_MOUNT := "/mnt/hdd/"
RESTIC_REPO := SSD_MOUNT + "backups/restic_repo"

# Update flake inputs and rebuild NixOS
update:
    #!/usr/bin/env zsh
    set -euo pipefail
    nix flake update nixpkgs nixpkgs-unstable home-manager ragenix nur --flake ~/dotfiles/nix-config
    printf "Update pinned R/RStudio packages too? They often aren't cached and rebuild from source. [y/N] "
    read -r ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        nix flake update nixpkgs-r --flake ~/dotfiles/nix-config
    fi
    sudo nixos-rebuild switch --flake 'path:/home/richard/dotfiles?dir=nix-config#nixos' --impure
    sudo systemctl restart home-manager-richard.service

# Rebuild NixOS and push dotfiles on success
rebuild:
    sudo nixos-rebuild switch --flake 'path:/home/richard/dotfiles?dir=nix-config#nixos' --impure
    sudo systemctl restart home-manager-richard.service

# push to gh
push:
    #!/usr/bin/env zsh
    cd ~/dotfiles
    git add .
    printf "Commit message (blank = 'update dotfiles'): "
    read msg
    msg="${msg:-update dotfiles}"
    { git commit -m "$msg" || true; }
    git push



# Remove generations older than 7 days, GC store, optimise, delete caches, organize and tidy up
putzfrau:
    sudo nix-collect-garbage --delete-older-than 14d
    nix store gc
    nix store optimise
    command -v go &>/dev/null && go clean -modcache -cache || { chmod -R u+w ~/go/pkg/mod ~/.cache/go-build 2>/dev/null || true; rm -rf ~/go/pkg/mod ~/.cache/go-build; }
    command -v npm &>/dev/null && npm cache clean --force || rm -rf ~/.npm/_cacache
    command -v uv &>/dev/null && uv cache clean || rm -rf ~/.cache/uv
    rm -rf ~/.cache/mozilla ~/.cache/mesa_shader_cache
    sudo journalctl --vacuum-time=2weeks
    restic cache --cleanup
    rm -rf ~/.cache/pip ~/.cache/fontconfig ~/.cache/thumbnails ~/.cache/R

# Run all backups: restic to local SDD, then sync to ProtonDrive and Google Drive
backup:
    #!/usr/bin/env zsh
    SSD_MOUNT="{{SSD_MOUNT}}"
    RESTIC_REPO="{{RESTIC_REPO}}"

    mountpoint -q "$SSD_MOUNT" || { echo "SDD not mounted at $HDD_MOUNT" >&2; exit 1; }

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



