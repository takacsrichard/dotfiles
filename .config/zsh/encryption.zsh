# Create a new age secret in ~/dotfiles/secrets/
# Usage: echo "KEY=value" | age-new-secret <name>
#        age-new-secret <name>   (then type content, Ctrl-D to finish)
age-new-secret() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: age-new-secret <name>" >&2
        echo "       echo 'KEY=val' | age-new-secret <name>" >&2
        return 1
    fi

    local secrets_dir="$HOME/dotfiles/secrets"
    local out="$secrets_dir/${name}.age"

    if [[ -f "$out" ]]; then
        echo "age-new-secret: $out already exists. Delete it first with age-del-secret." >&2
        return 1
    fi

    # Extract recipient public keys from secrets.nix (all ssh-ed25519 entries)
    local -a recipients
    while IFS= read -r key; do
        recipients+=(-r "$key")
    done < <(grep -oP '(?<=")(ssh-ed25519 [^"]+)' "$secrets_dir/secrets.nix")

    if [[ ${#recipients[@]} -eq 0 ]]; then
        echo "age-new-secret: could not extract recipient keys from $secrets_dir/secrets.nix" >&2
        return 1
    fi

    if [[ -t 0 ]]; then
        echo "Enter secret content (Ctrl-D when done):"
    fi

    age "${recipients[@]}" -o "$out" || { echo "age-new-secret: encryption failed" >&2; rm -f "$out"; return 1; }

    echo "Created: $out"
    echo "Next:"
    echo "  1. Add '\"${name}.age\".publicKeys = all;' to $secrets_dir/secrets.nix"
    echo "  2. Add 'age.secrets.\"${name}\" = { file = ../secrets/${name}.age; };' to configuration.nix"
    echo "  3. git add $out $secrets_dir/secrets.nix"
}

# Delete an age secret from ~/dotfiles/secrets/
# Usage: age-del-secret <name>
age-del-secret() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: age-del-secret <name>" >&2
        return 1
    fi

    local out="$HOME/dotfiles/secrets/${name}.age"
    if [[ ! -f "$out" ]]; then
        echo "age-del-secret: $out not found" >&2
        return 1
    fi

    local reply
    echo -n "Delete $out? [y/N] "
    read -r reply
    if [[ "$reply" =~ ^[Yy]$ ]]; then
        rm "$out"
        echo "Deleted: $out"
        echo "Remember:"
        echo "  1. Remove '\"${name}.age\"' from ~/dotfiles/secrets/secrets.nix"
        echo "  2. Remove 'age.secrets.\"${name}\"' from configuration.nix"
        echo "  3. git rm $out"
    else
        echo "Aborted."
    fi
}
