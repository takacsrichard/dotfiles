mntiphone() {
	idevicepair pair
	mkdir -p ~/iphone
	ifuse ~/iphone
}

unmntiphone(){
    fusermount -u ~/iphone
}

mntdisk() {
    local disks=()
    local i=1
    echo "Unmounted partitions:"
    while IFS= read -r line; do
        disks+=("$line")
        echo "  $i) $line"
        (( i++ ))
    done < <(lsblk -rpo NAME,TYPE,SIZE,MOUNTPOINT | awk '$2=="part" && $4=="" {print $1, $3}')

    if (( ${#disks[@]} == 0 )); then
        echo "No unmounted partitions found."
        return 1
    fi

    local choice
    read "choice?Pick number: "
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#disks[@]} )); then
        echo "Invalid choice."
        return 1
    fi

    local dev="${disks[$choice]%% *}"
    local out
    out="$(udisksctl mount -b "$dev")" || { echo "$out" >&2; return 1; }
    echo "$out"
    local mntpt="${out##* at }"
    mntpt="${mntpt%.}"
    [[ -d "$mntpt" ]] && cd "$mntpt"
}

unmntdisk() {
    local disks=()
    local i=1
    echo "Mounted partitions:"
    while IFS= read -r line; do
        disks+=("$line")
        echo "  $i) $line"
        (( i++ ))
    done < <(lsblk -rpo NAME,TYPE,SIZE,MOUNTPOINT | awk '$2=="part" && $4!="" && $4!="/" && $4!~/^\/(boot|home|var|tmp|run\/user|run\/lock|sys|proc|efi)/ {print $1, $3, $4}')

    if (( ${#disks[@]} == 0 )); then
        echo "No unmountable partitions found."
        return 1
    fi

    local choice
    read "choice?Pick number: "
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#disks[@]} )); then
        echo "Invalid choice."
        return 1
    fi

    local dev="${disks[$choice]%% *}"
    local mnt="${disks[$choice]##* }"
    local err
    if ! err="$(udisksctl unmount -b "$dev" 2>&1)"; then
        echo "$err" >&2
        if [[ "$err" == *"DeviceBusy"* || "$err" == *"target is busy"* ]]; then
            echo ""
            echo "Processes holding $mnt open:"
            fuser -mv "$mnt" 2>&1
        fi
        return 1
    fi
    echo "$err"
    cd ~
}
