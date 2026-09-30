# run okular and disown
o() {
    okular "$@" >/dev/null 2>&1 & disown
}

oz() {
    zathura "$@" >/dev/null 2>&1 & disown
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

# play yt audio; -d also downloads as opus with full metadata+thumbnail to the current directory
yt() {
    local download=false
    local soundcloud=false
    local -a args
    for arg in "$@"; do
        case "$arg" in
            -d)  download=true ;;
            -sc) soundcloud=true ;;
            *)   args+=("$arg") ;;
        esac
    done

    if [[ "$soundcloud" == true ]]; then
        if [[ "$download" == true ]]; then
            yt-dlp -x --audio-format mp3 --audio-quality 0 \
                --embed-thumbnail --embed-metadata \
                -o "%(title)s.%(ext)s" \
                "scsearch1:${args[*]}" &
        fi
        mpv --no-video \
            --ytdl-raw-options-append="force-ipv4=" \
            "ytdl://scsearch1:${args[*]}"
        return
    fi

    local cookie_file="${XDG_CACHE_HOME:-$HOME/.cache}/yt-cookies.txt"
    local -a cookie_args
    local used_cache=false

    # Use cached cookie file if < 24h old; otherwise re-extract from Firefox and save
    if [[ -f "$cookie_file" ]] && (( $(date +%s) - $(stat -c %Y "$cookie_file") < 86400 )); then
        cookie_args=(--cookies "$cookie_file")
        used_cache=true
    else
        cookie_args=(--cookies-from-browser firefox --cookies "$cookie_file")
    fi

    if [[ "$download" == true ]]; then
        yt-dlp -x --audio-format opus --audio-quality 0 \
            --embed-thumbnail --embed-metadata \
            "${cookie_args[@]}" --force-ipv4 \
            -o "%(title)s.%(ext)s" \
            "ytsearch1:${args[*]}" &
    fi

    mpv --no-video \
        --ytdl-raw-options-append="cookies-from-browser=firefox" \
        --ytdl-raw-options-append="extractor-args=youtube:player_client=web,mweb" \
        --ytdl-raw-options-append="force-ipv4=" \
        "ytdl://ytsearch1:${args[*]}"

    # Silently refresh the cookie file in the background after each fast-path call,
    # so the next invocation always hits the cache
    [[ $used_cache == true ]] && \
        yt-dlp --cookies-from-browser firefox --cookies "$cookie_file" \
            --skip-download -q "https://www.youtube.com/watch?v=dQw4w9WgXcQ" \
            &>/dev/null &|
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
# bitwarden vault password analyzer
pwanal() { python3 "$HOME/Documents/Projects/rbwcheck/pwanal.py" "$@"; }

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

# Find with fd; 1 match → copy immediately, multiple → pick from less -N
# Default: copies file path. -f: copies file contents.
cfd() {
    local copy_contents=false
    local -a fd_args=()
    for arg in "$@"; do
        [[ "$arg" == "-f" ]] && copy_contents=true || fd_args+=("$arg")
    done

    if (( ${#fd_args[@]} == 0 )); then
        echo "Usage: cfd [-f] <pattern> [fd-args...]" >&2
        return 1
    fi

    local -a files=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && files+=("$line")
    done < <(fd -u "${fd_args[@]}")

    _cfd_do_copy() {
        local target="$1"
        if [[ $copy_contents == true ]]; then
            copy "$target"
            echo "Copied contents: $target"
        else
            print -rn -- "$(realpath "$target")" | wl-copy
            echo "Copied path: $(realpath "$target")"
        fi
    }

    case ${#files[@]} in
        0)
            echo "cfd: no matches" >&2
            return 1
            ;;
        1)
            _cfd_do_copy "${files[1]}"
            ;;
        *)
            printf '%s\n' "${files[@]}" | less -N
            local choice
            read "choice?Copy which? [1-${#files[@]}] " </dev/tty
            if [[ "$choice" =~ '^[0-9]+$' ]] && (( choice >= 1 && choice <= ${#files[@]} )); then
                _cfd_do_copy "${files[$choice]}"
            else
                echo "cfd: invalid selection" >&2
                return 1
            fi
            ;;
    esac
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
