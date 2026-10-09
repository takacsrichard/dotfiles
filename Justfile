set shell := ["zsh", "-euo", "pipefail", "-c"]

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
    sudo nixos-rebuild switch --flake "path:$HOME/dotfiles?dir=nix-config#nixos" --impure
    sudo systemctl restart home-manager-richard.service

# Rebuild NixOS and push dotfiles on success
rebuild:
    sudo nixos-rebuild switch --flake "path:$HOME/dotfiles?dir=nix-config#nixos" --impure
    sudo systemctl restart home-manager-richard.service

# Remove generations older than 7 days, GC store, optimise, delete caches, organize and tidy up
putzfrau:
    ~/dotfiles/scripts/putzfrau.sh

# Run all backups: restic to local SSD, then sync to ProtonDrive and Google Drive
backup:
    ~/dotfiles/scripts/backup.sh



