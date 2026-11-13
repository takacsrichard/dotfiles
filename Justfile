set shell := ["zsh", "-euo", "pipefail", "-c"]

# Format nix-config (nixfmt/statix/deadnix) + shell scripts (shfmt) + python scripts (ruff)
fmt:
    #!/usr/bin/env zsh
    set -euo pipefail
    (cd nix-config && nix fmt)
    # shfmt <3.14.1 (pinned nixpkgs has 3.13.1) misparses glob bracket
    # expressions in array literals as array-index syntax - pull from
    # nixpkgs-unstable instead until the fix reaches nixos-26.05
    nix run github:nixos/nixpkgs/nixpkgs-unstable#shfmt -- -w -i 2 \
        scripts/backup.sh scripts/backup-disk.sh scripts/btrfs-heatmap.sh \
        scripts/smartctl-test.sh scripts/thermal-guard.sh scripts/reset-touchpad
    nix run nixpkgs#ruff -- format \
        scripts/disk-usage.py scripts/paperless-dump-sync.py scripts/touchpad-filter \
        scripts/utils/td-wrapper scripts/paperless/sync.py
    nix run nixpkgs#ruff -- check --fix \
        scripts/disk-usage.py scripts/paperless-dump-sync.py scripts/touchpad-filter \
        scripts/utils/td-wrapper scripts/paperless/sync.py

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
    just fmt
    nix flake check ./nix-config --impure
    sudo nixos-rebuild switch --flake "path:$HOME/dotfiles?dir=nix-config#nixos" --impure
    sudo systemctl restart home-manager-richard.service

# Rebuild NixOS and push dotfiles on success
rebuild:
    just fmt
    nix flake check ./nix-config --impure
    sudo nixos-rebuild switch --flake "path:$HOME/dotfiles?dir=nix-config#nixos" --impure
    sudo systemctl restart home-manager-richard.service

# Roll back to the previous NixOS generation
rollback:
    sudo nixos-rebuild switch --rollback
    sudo systemctl restart home-manager-richard.service

check:
  nix flake check ./nix-config --impure

# Run all backups: restic to local SSD, then sync to ProtonDrive and Google Drive
backup:
    ~/dotfiles/scripts/backup.sh

# Rotate the gh CLI token: paste the new one, re-encrypts secrets/gh-token.age
set-gh-token:
    #!/usr/bin/env zsh
    set -euo pipefail
    printf "New GitHub token: "
    read -rs token
    echo
    printf '%s' "$token" | age \
        -r "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJ+P9vVrcs/+sE0waSj0r6n27R+Ay20CQ+TvMbmZjKG" \
        -r "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHgJXEIeGmiXHaF5VL2ud1QH9MF2krC2VB50RAsPGfyw" \
        -o ~/dotfiles/secrets/gh-token.age
    echo "secrets/gh-token.age updated. Now run: just rebuild"



