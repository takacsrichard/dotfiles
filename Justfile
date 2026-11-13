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

# Encrypt a typed value (tokens, passwords) to secrets/<name>.age, using the
# recipients already declared for it in secrets/secrets.nix - e.g.
# `just set-secret gh-token`
set-secret name:
    #!/usr/bin/env zsh
    set -euo pipefail
    name="{{name}}"
    keys=("${(@f)$(nix eval --impure --raw --expr "let s = import ./secrets/secrets.nix; in builtins.concatStringsSep \"\n\" s.\"${name}.age\".publicKeys")}")
    args=()
    for k in "${keys[@]}"; do args+=(-r "$k"); done
    printf "Value for %s: " "$name"
    read -rs val
    echo
    printf '%s' "$val" | age "${args[@]}" -o "secrets/${name}.age"
    echo "secrets/${name}.age updated. Now run: just rebuild"

# Encrypt an existing file (VPN configs, etc.) to secrets/<name>.age, using the
# recipients already declared for it in secrets/secrets.nix - e.g.
# `just set-secret-file atvpn.conf ~/Downloads/atvpn.conf`
set-secret-file name path:
    #!/usr/bin/env zsh
    set -euo pipefail
    name="{{name}}"
    path="{{path}}"
    keys=("${(@f)$(nix eval --impure --raw --expr "let s = import ./secrets/secrets.nix; in builtins.concatStringsSep \"\n\" s.\"${name}.age\".publicKeys")}")
    args=()
    for k in "${keys[@]}"; do args+=(-r "$k"); done
    age "${args[@]}" -o "secrets/${name}.age" "$path"
    echo "secrets/${name}.age updated. Now run: just rebuild"



