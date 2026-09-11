# Interactive rollback: pick a profile (system / home-manager / user),
# list recent generations, switch to one.
rb() {
    local -A profiles
    local -a profile_names

    [[ -d /nix/var/nix/profiles/system ]] && {
        profiles[system]="/nix/var/nix/profiles/system"
        profile_names+=(system)
    }

    local hm_path=""
    if [[ -d "$HOME/.local/state/nix/profiles/home-manager" ]]; then
        hm_path="$HOME/.local/state/nix/profiles/home-manager"
    elif [[ -d "/nix/var/nix/profiles/per-user/$USER/home-manager" ]]; then
        hm_path="/nix/var/nix/profiles/per-user/$USER/home-manager"
    fi
    [[ -n "$hm_path" ]] && {
        profiles[home-manager]="$hm_path"
        profile_names+=(home-manager)
    }

    local user_path="/nix/var/nix/profiles/per-user/$USER/profile"
    [[ -d "$user_path" ]] && {
        profiles[user]="$user_path"
        profile_names+=(user)
    }

    if (( ${#profile_names[@]} == 0 )); then
        echo "No Nix profiles found." >&2
        return 1
    fi

    echo "Available profiles:"
    local i=1
    for name in "${profile_names[@]}"; do
        echo "  $i) $name  (${profiles[$name]})"
        (( i++ ))
    done

    local choice
    read "choice?Pick profile number: "
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#profile_names[@]} )); then
        echo "Invalid choice." >&2
        return 1
    fi

    local profile_name="${profile_names[$choice]}"
    local profile_path="${profiles[$profile_name]}"
    local needs_sudo=false
    [[ "$profile_name" == "system" ]] && needs_sudo=true

    echo ""
    echo "Recent generations for '$profile_name':"
    if [[ "$needs_sudo" == true ]]; then
        sudo nix-env --profile "$profile_path" --list-generations 2>/dev/null
    else
        nix-env --profile "$profile_path" --list-generations 2>/dev/null
    fi
    echo ""

    local target
    read "target?Switch to generation number: "
    if ! [[ "$target" =~ ^[0-9]+$ ]]; then
        echo "Invalid generation number." >&2
        return 1
    fi

    echo "Switching '$profile_name' to generation $target..."
    if [[ "$needs_sudo" == true ]]; then
        sudo nix-env --profile "$profile_path" --switch-generation "$target" || return 1
        echo "Activating..."
        sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
    elif [[ "$profile_name" == "home-manager" ]]; then
        nix-env --profile "$profile_path" --switch-generation "$target" || return 1
        echo "Activating..."
        "$profile_path/activate"
    else
        nix-env --profile "$profile_path" --switch-generation "$target"
    fi
}
