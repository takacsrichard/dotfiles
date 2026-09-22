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

checkfs() {
    local report="/tmp/checkfs_report.txt"
    local disks=()
    local i=1
    local dev rest size fstype

    sudo -v || return 1

    echo "Scanning unmounted drives..."
    echo "(Supported: exfat, ext2/3/4, btrfs)"

    local mountpoint
    while IFS= read -r line; do
        dev="${line%% *}"
        rest="${line#* }"
        size="${rest%% *}"
        fstype="${rest##* }"
        mountpoint=$(lsblk -rno MOUNTPOINT "$dev" 2>/dev/null | head -1)
        [[ -n "$mountpoint" ]] && continue
        disks+=("$dev $size $fstype")
        echo "  $i) $dev  $size  [$fstype]"
        (( i++ ))
    done < <(lsblk -rpo NAME,TYPE,SIZE,FSTYPE | \
        awk '$2=="part" && $4~/^(exfat|ext[234]|btrfs)$/ {print $1, $3, $4}')

    if (( ${#disks[@]} == 0 )); then
        echo "No unmounted partitions with supported filesystems found."
        return 1
    fi

    local choices_raw
    read "choices_raw?Pick numbers to check (comma-separated, e.g. 1,3): "

    local -a choices
    choices=(${(s:,:)choices_raw})

    {
        echo "checkfs report — $(date)"
        echo "Mode: read-only / dry-run. No repairs made."
        echo "========================================"

        local entry choice
        for choice in "${choices[@]}"; do
            choice="${choice// /}"
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#disks[@]} )); then
                echo ""
                echo "Invalid selection: '$choice', skipping."
                continue
            fi

            entry="${disks[$choice]}"
            dev="${entry%% *}"
            rest="${entry#* }"
            size="${rest%% *}"
            fstype="${rest##* }"

            echo ""
            echo "--- $dev  $size  [$fstype] ---"

            case "$fstype" in
                exfat)          sudo env PATH="$PATH" fsck.exfat -n -v "$dev" ;;
                ext2|ext3|ext4) sudo env PATH="$PATH" e2fsck -n "$dev" ;;
                btrfs)          sudo env PATH="$PATH" btrfs check --readonly "$dev" ;;
            esac
        done

        echo ""
        echo "========================================"
        echo "Scan complete — $(date)"
    } > "$report" 2>&1

    echo "Done. Full results written to $report"
}
