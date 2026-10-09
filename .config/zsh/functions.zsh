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

chpwd() {
    [[ -o interactive && -t 1 ]] || return 0
    _ezals
}

epoch() { date -d @"$1" '+%Y-%m-%d %H:%M:%S %Z'; }

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


# --- R / LaTeX ---
rr()   { Rscript "$1" }
rrmd() { Rscript -e "rmarkdown::render('$1', output_format='pdf_document')" }
lmk()  { latexmk -pdf "$1" }

# z only exists once zoxide has been initialized, i.e. interactive shells.
# Without the builtin fallback, cd in a script is a silent no-op -- "command
# not found: z", and the script carries on in the wrong directory.
cd() {
    if (( $+functions[z] )); then
        z "$@"
    else
        builtin cd "$@"
    fi
}

