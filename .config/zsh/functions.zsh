ef() {
  local line tok
  for line in "${(@Oa)${(f)$(fc -ln 1)}}"; do
    for tok in ${(z)line}; do
      tok=${(Q)tok}
      [[ $tok == \~/* ]] && tok=$HOME/${tok#\~/}
      [[ $tok == /* && ${(L)tok} == *${(L)1}* && -f $tok ]] && {
        ${EDITOR:-nvim} "$tok"
        return
      }
    done
  done
  print -u2 "no match in history for: $1"
}

# run okular and disown
o() {
    okular "$@" >/dev/null 2>&1 & disown
}

oz() {
    zathura "$@" >/dev/null 2>&1 & disown
}

# TODO test pyfilemv as an alternative
mvln() {
  if (( $# < 2 || $# > 3 )); then
    echo "Usage: mvln <src> <dst> [root]" >&2
    return 1
  fi
  local src="$1" dst="$2" root="${3:-$HOME}"
  if [[ ! -e "$src" ]]; then
    echo "mvln: '$src' does not exist" >&2
    return 1
  fi
  local src_abs dst_abs
  src_abs=$(readlink -f "$src")
  command mv "$src" "$dst"
  # mv moves src INTO dst when dst is an existing directory, so the
  # real new path is dst/basename(src), not dst itself
  if [[ -d "$dst" ]]; then
    dst_abs=$(readlink -f "$dst/$(basename "$src_abs")")
  else
    dst_abs=$(readlink -f "$dst")
  fi
  # repoint any symlink under $root whose target resolves to src_abs
  find "$root" -xtype l 2>/dev/null | while read -r link; do
    [[ "$(readlink -f "$link")" == "$src_abs" ]] && ln -sfn "$dst_abs" "$link"
  done
}

epoch() { date -d @"$1" '+%Y-%m-%d %H:%M:%S %Z'; }

mvp() { mkdir -p "$(dirname "${@: -1}")" && command mv "$@"; }

mv() {
    local -a plain
    for arg in "$@"; do
        [[ "$arg" == -* ]] || plain+=("$arg")
    done

    if (( ${#plain[@]} >= 2 )); then
        local dest="${plain[-1]}"
        local -a srcs=("${plain[1,-2]}")
        for src in "${srcs[@]}"; do
            local dest_path
            [[ -d "$dest" ]] && dest_path="${dest%/}/$(basename "$src")" || dest_path="$dest"
            if [[ -e "$src" && -e "$dest_path" && "$(basename "$src")" == "$(basename "$dest_path")" ]]; then
                local born mod
                born=$(stat -c '%w' "$src" 2>/dev/null | cut -d. -f1)
                mod=$(stat -c '%y'  "$src" 2>/dev/null | cut -d. -f1)
                [[ "$born" == "-" || -z "$born" ]] && born="unknown"
                printf "  src  %s\n       born: %s  modified: %s\n" "$src" "$born" "$mod"
                born=$(stat -c '%w' "$dest_path" 2>/dev/null | cut -d. -f1)
                mod=$(stat -c '%y'  "$dest_path" 2>/dev/null | cut -d. -f1)
                [[ "$born" == "-" || -z "$born" ]] && born="unknown"
                printf "  dst  %s\n       born: %s  modified: %s\n" "$dest_path" "$born" "$mod"
                local reply
                read "reply?mv: overwrite '$(basename "$dest_path")'? [y/N] " </dev/tty
                [[ "$reply" != [Yy] ]] && { echo "Skipped: $src"; return 0; }
            fi
        done
    fi

    command mv "$@"
}

filecount() {
  local depth="${1:-1}"
  find . -mindepth 1 -maxdepth "$depth" -type d -print0 | while IFS= read -r -d '' dir; do
    printf '%s %s\n' "$(find "$dir" -type f | wc -l)" "$dir"
  done | sort -rn
}

temps() {
  sensors | awk '
    /mt7921/   { chip="wifi" }
    /acpitz/   { chip="mb" }
    /edge:/      { print "GPU:         " $2 }
    /Tctl:/      { print "CPU:         " $2 }
    /Composite:/ { print "SSD:         " $2 }
    /temp1:/ && chip=="wifi" { print "Wi-Fi:       " $2 }
    /temp1:/ && chip=="mb"   { print "Motherboard: " $2 }
  '
}

mpv() {
    local -a args
    for arg in "$@"; do
        case "$arg" in
		--shf) args+=(--shuffle) ;;
            --nv) args+=(--no-video) ;;
            --na) args+=(--no-audio) ;;
            *)    args+=("$arg") ;;
        esac
    done
    command mpv "${args[@]}"
}

# --- script wrappers ---

libcalc() {
    libreoffice --calc "$@"
}

# mkdir + cd in one
mkcd() {
    mkdir -p "$1" && cd "$1" && cpwd 
}

# Kill by name
killn() {
    kill ${(f)"$(pgrep "$1")"}
}

# Check files if identical
sametest() {
    if (( $# != 2 )); then
        echo "Usage: sametest <file1> <file2>"
        return 1
    fi

    if cmp -s "$1" "$2"; then
        echo "✓ Identical"
    else
        echo "✗ Different"
    fi
}

# IP info
myip() {
    local v4="$(curl -s -4 --max-time 5 ifconfig.me 2>/dev/null)"
    local v6="$(curl -s -6 --max-time 5 ifconfig.me 2>/dev/null)"
    local info="$(curl -s --max-time 5 ipinfo.io 2>/dev/null)"

    local city="$(echo "$info"    | jq -r '.city    // "N/A"')"
    local region="$(echo "$info"  | jq -r '.region  // "N/A"')"
    local country="$(echo "$info" | jq -r '.country // "N/A"')"
    local org="$(echo "$info"     | jq -r '.org     // "N/A"')"

    echo "IPv4:     ${v4:-N/A}"
    echo "IPv6:     ${v6:-N/A}"
    echo "Location: $city, $region, $country"
    echo "ISP:      $org"
}

# --- Screen shortcut ---
sco() {
    if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
        sleep 1 && hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
    else
        dbus-send --session --print-reply --dest=org.kde.kglobalaccel /component/org_kde_powerdevil org.kde.kglobalaccel.Component.invokeShortcut string:'Turn Off Screen'
    fi
}

# Go up N directories
up() {
    local n="${1:-1}"
    repeat "$n"; do cd ..; done
}

# Copy a file's contents, or a command's output, to the clipboard
copy() {
    command -v wl-copy &>/dev/null || { echo "wl-copy not found" >&2; return 1; }
    if [[ -f "$1" ]]; then
        wl-copy < "$1"
    else
        eval "$@" | wl-copy
    fi
}

# Copy the last command run
copylast() {
    fc -ln -1 | sed 's/^[[:space:]]*//' | wl-copy
}

toppct() {
    local include_hidden=false
    local dir=""
    local arg
    for arg in "$@"; do
        if [[ "$arg" == "-a" ]]; then
            include_hidden=true
        else
            dir="$arg"
        fi
    done

    [[ -z "$dir" ]] && dir="$PWD"

    if [[ "$include_hidden" == true ]]; then
        find "$dir" -type f -print0 | xargs -0 du -b | sort -rn | awk '
        BEGIN { top5=0; top10=0; total=0; count=0 }
        { size[count]=$1; total+=$1; count++ }
        END {
            for(i=0;i<count;i++) {
                if(i<5) top5+=size[i]
                if(i<10) top10+=size[i]
            }
            printf "Top 5  files: %.1f%% of total\n", (top5/total)*100
            printf "Top 10 files: %.1f%% of total\n", (top10/total)*100
        }'
    else
        find "$dir" -type f -not -path '*/.*' -print0 | xargs -0 du -b | sort -rn | awk '
        BEGIN { top5=0; top10=0; total=0; count=0 }
        { size[count]=$1; total+=$1; count++ }
        END {
            for(i=0;i<count;i++) {
                if(i<5) top5+=size[i]
                if(i<10) top10+=size[i]
            }
            printf "Top 5  files: %.1f%% of total\n", (top5/total)*100
            printf "Top 10 files: %.1f%% of total\n", (top10/total)*100
        }'
    fi
}


# Jump to zoxide target and copy the resulting path to clipboard
zcpwd() {
    z "$@" && copy pwd
}

# Copy full path of cwd, or of a given file/folder, to clipboard
cpwd() {
    if (( $# == 0 )); then
        pwd | tr -d '\n' | wl-copy
        echo "Copied: $(pwd)"
    else
        local target
        target=$(realpath "$1")
        print -rn -- "$target" | wl-copy
        echo "Copied: $target"
    fi
}

# Find with fd, open matches in nvim (max 10); usage: nfd <pattern> [search_dir]
nfd() {
    if (( $# == 0 )); then
        echo "Usage: nfd <pattern> [search_dir]" >&2
        return 1
    fi

    local pattern="$1"
    local search_dir="${2:-.}"
    local -a files

    while IFS= read -r line; do
        [[ -n "$line" ]] && files+=("$line")
    done < <(fd -H -- "$pattern" "$search_dir")

    local count=${#files[@]}

    if (( count == 0 )); then
        echo "nfd: no matches for '$pattern'" >&2
        return 1
    fi

    if (( count > 10 )); then
        echo "nfd: $count matches, opening first 10" >&2
        files=("${files[1,10]}")
    else
        echo "nfd: $count match(es)" >&2
    fi

    nvim "${files[@]}"
}

# Remove all empty directories under a given path (depth-first, with confirmation)
# Usage: rmemptydirs [path]   (defaults to current dir)
rmemptydirs() {
    local force=0
    if [[ "$1" == "-f" ]]; then
        force=1
        shift
    fi

    local target="${1:-.}"
    if [[ ! -d "$target" ]]; then
        echo "rmemptydirs: '$target' is not a directory" >&2
        return 1
    fi

    local dirs
    dirs=$(find "$target" -depth -mindepth 1 -type d -empty 2>/dev/null)
    if [[ -z "$dirs" ]]; then
        echo "No empty directories in '$target'"
        return 0
    fi

    local count
    count=$(printf '%s\n' "$dirs" | wc -l)
    printf '%s\n' "$dirs"
    echo
    printf 'Remove %d empty director%s? [y/N] ' "$count" "$([[ $count -eq 1 ]] && echo y || echo ies)"

    local reply='y'
    if (( ! force )); then
        read -r reply
    else
        echo y
    fi

    if [[ "$reply" =~ ^[Yy]$ ]]; then
        find "$target" -depth -mindepth 1 -type d -empty -delete
        echo "Removed $count empty director$([[ $count -eq 1 ]] && echo y || echo ies)."
    else
        echo "Aborted."
    fi
}

