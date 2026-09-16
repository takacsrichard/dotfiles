# run okular and disown
o() {
    okular "$@" >/dev/null 2>&1 & disown
}

oz() {
    zathura "$@" >/dev/null 2>&1 & disown
}


# play yt audio; -d also downloads as opus with full metadata+thumbnail to ~/Music/yt_ddl/
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
            mkdir -p "$HOME/Music/yt_ddl"
            yt-dlp -x --audio-format mp3 --audio-quality 0 \
                --embed-thumbnail --embed-metadata \
                -o "$HOME/Music/yt_ddl/%(title)s.%(ext)s" \
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
        mkdir -p "$HOME/Music/yt_ddl"
        yt-dlp -x --audio-format opus --audio-quality 0 \
            --embed-thumbnail --embed-metadata \
            "${cookie_args[@]}" --force-ipv4 \
            -o "$HOME/Music/yt_ddl/%(title)s.%(ext)s" \
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
# irq balance checker
irqgini() { python3 "$HOME/scripts/irqgini.py" "$@"; }
# bitwarden vault password analyzer
pwanal() { python3 "$HOME/Documents/Projects/rbwcheck/pwanal.py" "$@"; }

libcalc() {
    libreoffice --calc "$@"
}

# mkdir + cd in one
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Compress PDFs in the current directory
pdfcompress() {
    local pdfs=(*.pdf(.N))   # (.N) => regular files only, no error if none

    if (( ${#pdfs[@]} == 0 )); then
        echo "No PDFs found in current directory."
        return 1
    fi

    mkdir -p orig_pdfs

    local pdf filename
    for pdf in $pdfs; do
        filename="$(basename "$pdf")"
        mv "$pdf" "orig_pdfs/$filename"
        echo "Compressing $filename..."
        if gs -sDEVICE=pdfwrite \
              -dCompatibilityLevel=1.4 \
              -dPDFSETTINGS=/ebook \
              -dNOPAUSE \
              -dQUIET \
              -dBATCH \
              -sOutputFile="$filename" \
              "orig_pdfs/$filename"; then
            echo "✓ $filename"
        else
            echo "✗ Failed: $filename"
        fi
    done

    echo "Done. Originals in ./orig_pdfs/"
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

# Universal extract
extract() {
    local into_folder=false
    local file=""
    local arg
    for arg in "$@"; do
        case "$arg" in
            -f) into_folder=true ;;
            *)  file="$arg" ;;
        esac
    done

    if [[ -z "$file" ]]; then
        echo "Usage: extract [-f] <file>"
        return 1
    fi

    if [[ ! -e "$file" ]]; then
        echo "File not found: $file"
        return 1
    fi

    if [[ "$into_folder" == true ]]; then
        local folder="$(basename "$file" | sed -E 's/\.(tar\.(gz|bz2|xz)|tgz|zip|gz|7z)$//')"
        mkdir -p "$folder"
        case "$file" in
            *.tar.gz|*.tgz) tar xzf "$file" -C "$folder" ;;
            *.tar.bz2)      tar xjf "$file" -C "$folder" ;;
            *.tar.xz)       tar xJf "$file" -C "$folder" ;;
            *.zip)          unzip "$file" -d "$folder" ;;
            *.gz)           cp "$file" "$folder/" && gunzip "$folder/$(basename "$file")" ;;
            *.7z)           7z x "$file" -o"$folder" ;;
            *)              echo "Unknown format: $file"; return 1 ;;
        esac
        echo "Extracted into ./$folder/"
    else
        case "$file" in
            *.tar.gz|*.tgz) tar xzf "$file" ;;
            *.tar.bz2)      tar xjf "$file" ;;
            *.tar.xz)       tar xJf "$file" ;;
            *.zip)          unzip "$file" ;;
            *.gz)           gunzip "$file" ;;
            *.7z)           7z x "$file" ;;
            *)              echo "Unknown format: $file"; return 1 ;;
        esac
    fi
}

# Archive a directory (or cwd) into a dated tar.gz
archive() {
    local target outname
    if (( $# > 0 )); then
        target="$1"
        outname="$(basename "$1")"
    else
        target="$PWD"
        outname="$(basename "$PWD")"
    fi

    local filecount="$(find "$target" -type f | wc -l)"
    if (( filecount > 20 )); then
        local confirm
        read "confirm?Warning: $filecount files found in '$target'. Continue? [y/N] "
        if [[ "$confirm" != [Yy] ]]; then
            echo "Aborted."
            return 1
        fi
    fi

    local outfile="${outname}_$(date +%Y%m%d).tar.gz"
    local tmpfile="/tmp/$outfile"

    tar czf "$tmpfile" -C "$target" --transform 's|^\./||' .
    mv "$tmpfile" "$outfile"
    echo "Archived $filecount files → $outfile"
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

# Init a local dir and push to gitlab as takacsrichard/<name>
# Usage: ginit -n <repo_name> [-c "commit message"] [-p (public)]
ginit() {
    local repo_name=""
    local commit_msg="initial commit"
    local visibility="private"

    while getopts ":n:c:p" opt; do
        case "$opt" in
            n) repo_name="$OPTARG" ;;
            c) commit_msg="$OPTARG" ;;
            p) visibility="public" ;;
            :) echo "ginit: -$OPTARG requires an argument" >&2; return 1 ;;
            \?) echo "ginit: unknown option -$OPTARG" >&2; return 1 ;;
        esac
    done

    if [[ -z "$repo_name" ]]; then
        echo "Usage: ginit -n <repo_name> [-c \"commit message\"] [-p (public)]" >&2
        return 1
    fi

    local current_dir="$PWD"
    local confirm
    read "confirm?Push '${current_dir}' to gitlab:takacsrichard/${repo_name}.git? [y/N] " </dev/tty
    if [[ "$confirm" != [Yy] ]]; then
        echo "Aborted."
        return 1
    fi

    # Safety: bail out if the repo already has commits (i.e. this isn't a fresh init)
    if git rev-parse HEAD &>/dev/null 2>&1; then
        local existing_remote
        existing_remote="$(git remote get-url origin 2>/dev/null || echo '(none)')"
        echo "ginit: this directory already has git history." >&2
        echo "  Current remote: $existing_remote" >&2
        echo "  Use 'git remote set-url origin <url>' manually if you really want to change it." >&2
        return 1
    fi

    git init

    local remote_url="git@gitlab.com:takacsrichard/${repo_name}.git"
    if git remote get-url origin &>/dev/null; then
        git remote set-url origin "$remote_url"
    else
        git remote add origin "$remote_url"
    fi

    git add .

    # Show what's about to be committed and ask for confirmation
    echo ""
    git status
    echo ""
    local proceed
    read "proceed?Commit and push the above to gitlab:takacsrichard/${repo_name}.git? [y/N] " </dev/tty
    if [[ "$proceed" != [Yy] ]]; then
        echo "Aborted. Remote is set to: git@gitlab.com:takacsrichard/${repo_name}.git"
        echo "Files are staged but not committed — re-run ginit when ready."
        # Un-stage everything so the working tree is clean for a re-run
        git reset HEAD -- . &>/dev/null
        return 1
    fi

    # Only commit if there is something to commit
    if ! git diff --cached --quiet; then
        git commit -m "$commit_msg"
    fi

    # Create the GitLab repo via API before pushing so git push doesn't hang
    # waiting for a non-existent remote. Token fetched from rbw (Bitwarden).
    local gl_token
    gl_token="$(rbw get "gitlab stuff personal access token" 2>/dev/null)"
    if [[ -z "$gl_token" ]]; then
        echo "ginit: warning: could not fetch GitLab token from rbw — skipping remote repo creation." >&2
        echo "  If the repo doesn't exist on GitLab, the push will fail. Create it manually first." >&2
    else
        local api_resp http_code
        # Use --write-out to get the HTTP status code separately from the body
        api_resp=$(curl -sfS --max-time 15 \
            --write-out '\n%{http_code}' \
            --header "PRIVATE-TOKEN: $gl_token" \
            --header "Content-Type: application/json" \
            --data "{\"name\":\"${repo_name}\",\"visibility\":\"${visibility}\",\"initialize_with_readme\":false}" \
            "https://gitlab.com/api/v4/projects" 2>&1)
        http_code="${api_resp##*$'\n'}"
        case "$http_code" in
            201) echo "  → GitLab repo created (${visibility}): https://gitlab.com/takacsrichard/${repo_name}" ;;
            400) echo "  → GitLab repo already exists, skipping creation." ;;
            *)   echo "ginit: GitLab API returned HTTP ${http_code} — continuing anyway." >&2 ;;
        esac
    fi

    git branch -M main &&
    git push --set-upstream origin main
}

# Convert FLAC to Opus; -d deletes originals, -b <rate> sets bitrate (default: 128k)
ftoo() {
    local ffmpeg_bin rm_bin
    ffmpeg_bin="$(whence -p ffmpeg 2>/dev/null || whence ffmpeg 2>/dev/null)"
    rm_bin="$(whence -p rm 2>/dev/null || whence rm 2>/dev/null)"
    if [[ -z "$ffmpeg_bin" ]]; then
        echo "ftoo: ffmpeg not found — add it to your nix config or run: nix shell nixpkgs#ffmpeg" >&2
        return 1
    fi

    local delete=false bitrate="128k" path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--delete)  delete=true; shift ;;
            -b|--bitrate) bitrate="$2"; shift 2 ;;
            *)            path="$1"; shift ;;
        esac
    done

    if [[ -z "$path" ]]; then
        echo "Usage: ftoo <file|dir> [-d] [-b <bitrate>]"
        return 1
    fi

    local -a files=()
    if [[ -f "$path" ]]; then
        files=("$path")
    elif [[ -d "$path" ]]; then
        files=("${path}"/**/*.flac(.N))
    else
        echo "ftoo: '$path': not a file or directory" >&2
        return 1
    fi

    if (( ${#files[@]} == 0 )); then
        echo "ftoo: no FLAC files found in '$path'" >&2
        return 1
    fi

    local count=0 failed=0 skipped=0 overwrite_all=false
    local input output confirm
    for input in "${files[@]}"; do
        output="${input%.flac}.opus"
        if [[ -f "$output" ]] && [[ $overwrite_all == false ]]; then
            read "confirm?'${output:t}' exists. Overwrite? [y / N / Y=all] " </dev/tty
            case "$confirm" in
                Y) overwrite_all=true ;;
                [y]) ;;
                *) skipped=$(( skipped + 1 )); continue ;;
            esac
        fi
        printf 'Converting: %s\n' "${input:t}"
        if "$ffmpeg_bin" -loglevel warning -i "$input" -c:a libopus -b:a "$bitrate" \
                  -vbr on -application audio -y "$output"; then
            [[ $delete == true ]] && [[ -n "$rm_bin" ]] && "$rm_bin" "$input"
            count=$(( count + 1 ))
        else
            printf 'Failed: %s\n' "$input" >&2
            failed=$(( failed + 1 ))
        fi
    done

    (( ${#files[@]} > 1 )) && printf 'Done: %d converted, %d skipped, %d failed\n' "$count" "$skipped" "$failed"
}

source "$HOME/dotfiles/.config/zsh/functions/identical.zsh"
source "$HOME/dotfiles/.config/zsh/functions/is-subset.zsh"

function download_insta_reels {
    local reels_dir=~/Downloads/reels
    mkdir -p "$reels_dir"
    grep -oP 'https://www\.instagram\.com/reel/[^"]+' ~/Downloads/saved_posts.json | sort -u > "$reels_dir/reel_links.txt"
    yt-dlp --cookies-from-browser firefox -P "$reels_dir" -a "$reels_dir/reel_links.txt"
    echo "=== IN LIST BUT NOT DOWNLOADED ===" && \
    comm -23 \
        <(grep -oP 'reel/\K[^/]+' "$reels_dir/reel_links.txt" | sort) \
        <(ls "$reels_dir"/*.mp4 | grep -oP '\[\K[^\]]+(?=\])' | sort) | wc -l
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
