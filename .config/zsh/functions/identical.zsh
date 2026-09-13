# Compare N paths for identity.
# Usage: identical [MODE] [-rs N | -st C:P] <path1> <path2> [path3 ...]
#
# Modes (mutually exclusive; default = byte-for-byte via cmp):
#   -d       diff mode  : diff for files, diff -qr for dirs/archives (2 paths only)
#   -q       quick mode : filename + filesize only, no I/O
#
# Options:
#   -rs N    randomly sample N files byte-for-byte
#   -st C:P  auto-sample: C% confident ≤P% of files differ  (e.g. -st 95:1)
#            both require dirs or archives, not plain files
#
# Supported inputs: plain files, directories,
#   .tar / .tar.{gz,bz2,xz,zst} / .tgz, .zip, .7z
# N≥2: all paths are compared against the first (reference)

identical() {
    local mode=cmp rs_n=0 _st_arg=''

    while [[ $# -gt 0 && "$1" == -* ]]; do
        case "$1" in
            -d)   mode=diff;      shift ;;
            -q)   mode=quick;     shift ;;
            -rs)  rs_n="$2";      shift 2 ;;
            -st)  _st_arg="$2";   shift 2 ;;
            --)   shift; break ;;
            *)    printf 'identical: unknown option %s\n' "$1" >&2; return 1 ;;
        esac
    done

    local -a paths=("$@")

    if (( ${#paths} < 2 )); then
        cat >&2 <<'USAGE'
Usage: identical [MODE] [-rs N | -st C:P] <path1> <path2> [path3 ...]
  Modes:  (default) full cmp  |  -d diff (2 paths only)  |  -q quick (size+name)
  -rs N      random-sample N files byte-for-byte
  -st C:P    auto-sample: C% confident ≤P% of files differ  (e.g. -st 95:1)
  Types:  files, dirs, .tar[.gz|.bz2|.xz|.zst], .tgz, .zip, .7z
  N≥2:   all paths compared against the first (reference)
USAGE
        return 1
    fi

    if [[ "$mode" == diff && ${#paths} -gt 2 ]]; then
        printf 'identical: -d only supports 2 paths\n' >&2; return 1
    fi

    local p
    for p in "${paths[@]}"; do
        [[ -e "$p" ]] || { printf 'identical: %s: does not exist\n' "$p" >&2; return 1; }
    done

    # ── helpers ────────────────────────────────────────────────────────────────

    _ident_type() {
        local p="$1" pl="${1:l}"
        if   [[ -d "$p" ]];                                     then echo dir
        elif [[ "$pl" =~ \.(tar(\.(gz|bz2|xz|zst))?|tgz)$ ]]; then echo tar
        elif [[ "$pl" =~ \.zip$ ]];                             then echo zip
        elif [[ "$pl" =~ \.7z$  ]];                             then echo 7z
        elif [[ -f "$p" ]];                                     then echo file
        else echo unknown; fi
    }

    _ident_strip_prefix() {
        local raw="$1"
        [[ -z "$raw" ]] && return
        local prefix
        prefix=$(printf '%s\n' "$raw" | awk -F'\t' '{
            idx = index($2, "/")
            print (idx > 0) ? substr($2, 1, idx-1) : ""
        }' | sort -u)
        if [[ $(printf '%s\n' "$prefix" | wc -l) -eq 1 && -n "$prefix" ]]; then
            local pfx="${prefix}/"
            printf '%s\n' "$raw" | awk -F'\t' -v pfx="$pfx" '{
                path = $2
                if (index(path, pfx) == 1) path = substr(path, length(pfx)+1)
                printf "%s\t%s\n", $1, path
            }' | sort -t$'\t' -k2
        else
            printf '%s\n' "$raw" | sort -t$'\t' -k2
        fi
    }

    _ident_list() {
        local p="$1" type="$2"
        local raw
        case "$type" in
            dir)
                find "$p" -type f -printf '%s\t%P\n' | sort -t$'\t' -k2
                return ;;
            tar)
                raw=$(tar -tv -f "$p" 2>/dev/null | grep '^-' | awk '{
                    match($0, /^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +/)
                    path = substr($0, RLENGTH+1)
                    printf "%s\t%s\n", $3, path
                }') ;;
            zip)
                raw=$(unzip -l "$p" 2>/dev/null | awk '
                    /^[[:space:]]*[0-9]+ +[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
                        sz = $1; line = $0
                        sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9-]+[[:space:]]+[0-9:]+[[:space:]]+/, "", line)
                        if (line != "" && line !~ /^[0-9]+ file/)
                            printf "%s\t%s\n", sz, line
                    }') ;;
            7z)
                raw=$(7z l "$p" 2>/dev/null | awk '
                    /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [^D]/ {
                        sz = $4; line = $0
                        sub(/^[0-9-]+ +[0-9:]+ +[^ ]+ +[0-9]+ +[0-9]+ +/, "", line)
                        if (line != "") printf "%s\t%s\n", sz, line
                    }') ;;
            file)
                printf '%s\t%s\n' "$(stat -c '%s' "$p")" "$(basename "$p")"
                return ;;
            *)
                printf 'identical: unsupported type for %s\n' "$p" >&2; return 1 ;;
        esac
        _ident_strip_prefix "$raw"
    }

    # temp dirs tracked for cleanup; inner helpers access this via dynamic scoping
    local -a _ident_tmpdirs=()

    # Extract archive to temp dir (or return dir/file path unchanged). Prints result path.
    _ident_to_workdir() {
        local p="$1" t="$2"
        if [[ "$t" == dir || "$t" == file ]]; then
            printf '%s' "$p"; return
        fi
        local tmp
        tmp=$(mktemp -d)
        _ident_tmpdirs+=("$tmp")
        case "$t" in
            tar) tar   -xf "$p" -C "$tmp" 2>/dev/null ;;
            zip) unzip -q  "$p" -d "$tmp" 2>/dev/null ;;
            7z)  7z x      "$p" -o"$tmp" -y >/dev/null 2>&1 ;;
        esac
        # unwrap single top-level dir (e.g. archive extracted as archive-name/)
        local subs=("$tmp"/*(N/)) files=("$tmp"/*(N))
        if (( ${#subs} == 1 && ${#files} == 1 )); then
            printf '%s' "${subs[1]}"
        else
            printf '%s' "$tmp"
        fi
    }

    _ident_cleanup() {
        local t
        for t in "${_ident_tmpdirs[@]}"; do rm -rf "$t"; done
        unfunction _ident_type _ident_list _ident_strip_prefix \
                   _ident_to_workdir _ident_cleanup 2>/dev/null
    }

    # detect types for all paths
    local -a types=()
    local i
    for (( i=1; i<=${#paths}; i++ )); do
        types+=($(_ident_type "${paths[$i]}"))
    done

    # ── -st: compute sample size ──────────────────────────────────────────────
    if [[ -n "$_st_arg" ]]; then
        local st_conf="${_st_arg%%:*}"
        local st_thresh="${_st_arg##*:}"

        if ! [[ "$st_conf" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( st_conf <= 0 || st_conf >= 100 )); then
            printf 'identical: -st confidence must be in (0, 100) — for a full scan, omit -st\n' >&2
            _ident_cleanup; return 1
        fi
        if ! [[ "$st_thresh" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( st_thresh <= 0 )); then
            printf 'identical: -st threshold must be > 0 (percent of files allowed to differ)\n' >&2
            _ident_cleanup; return 1
        fi

        rs_n=$(python3 -c "
import math
conf   = $st_conf   / 100.0
thresh = min($st_thresh / 100.0, 0.9999)
print(math.ceil(math.log(1 - conf) / math.log(1 - thresh)))
")
        # cap at actual file count in reference
        local ref_count
        if [[ "${types[1]}" == dir ]]; then
            ref_count=$(find "${paths[1]}" -type f | wc -l)
        else
            ref_count=$(_ident_list "${paths[1]}" "${types[1]}" | wc -l)
        fi
        (( rs_n > ref_count )) && rs_n=$ref_count

        printf 'Statistical sample: %d files (%.0f%% confidence, ≤%s%% difference threshold)\n' \
               "$rs_n" "$st_conf" "$st_thresh"
    fi

    # ── random-sample / statistical-sample mode ───────────────────────────────
    if (( rs_n > 0 )); then
        for (( i=1; i<=${#types}; i++ )); do
            if [[ "${types[$i]}" == file ]]; then
                printf 'identical: -rs/-st requires dirs or archives, not plain files\n' >&2
                _ident_cleanup; return 1
            fi
        done

        local -a workdirs=()
        for (( i=1; i<=${#paths}; i++ )); do
            workdirs+=("$(_ident_to_workdir "${paths[$i]}" "${types[$i]}")")
        done

        local ref="${workdirs[1]}" ref_name="${paths[1]}"
        local total_diffs=0 total_only=0 checked=0

        while IFS= read -r rel; do
            (( checked++ ))
            for (( i=2; i<=${#workdirs}; i++ )); do
                local other="${workdirs[$i]}" oname="${paths[$i]}"
                if [[ ! -f "$other/$rel" ]]; then
                    printf 'Only in %s (not %s): %s\n' "$ref_name" "$oname" "$rel"
                    (( total_only++ ))
                elif ! cmp -s "$ref/$rel" "$other/$rel"; then
                    printf 'Differ (%s vs %s): %s\n' "$ref_name" "$oname" "$rel"
                    (( total_diffs++ ))
                fi
            done
        done < <(find "$ref" -type f -printf '%P\n' | shuf -n "$rs_n")

        if (( total_diffs == 0 && total_only == 0 )); then
            printf 'All %d sampled files are identical\n' "$checked"
        else
            printf '%d/%d differ, %d only in first\n' "$total_diffs" "$checked" "$total_only"
        fi
        _ident_cleanup; return
    fi

    # ── quick mode (-q) ───────────────────────────────────────────────────────
    if [[ "$mode" == quick ]]; then
        local ref_list any_diff=0
        ref_list=$(_ident_list "${paths[1]}" "${types[1]}")
        for (( i=2; i<=${#paths}; i++ )); do
            local other_list out ret
            other_list=$(_ident_list "${paths[$i]}" "${types[$i]}")
            out=$(diff <(printf '%s\n' "$ref_list") <(printf '%s\n' "$other_list"))
            ret=$?
            if (( ret != 0 )); then
                any_diff=1
                (( ${#paths} > 2 )) && printf '── %s vs %s ──\n' "${paths[1]}" "${paths[$i]}"
                printf '%s\n' "$out" | awk -F'\t' -v a="${paths[1]}" -v b="${paths[$i]}" '
                    /^</ { printf "Only in %s: %s (%s bytes)\n", a, $2, substr($1,3) }
                    /^>/ { printf "Only in %s: %s (%s bytes)\n", b, $2, substr($1,3) }
                '
            fi
        done
        if (( !any_diff )); then
            if   (( ${#paths} == 2 )); then echo "Identical (metadata)"
            else printf 'All %d paths identical (metadata)\n' "${#paths}"; fi
        fi
        _ident_cleanup; return
    fi

    # ── diff mode (-d) — 2 paths only ────────────────────────────────────────
    if [[ "$mode" == diff ]]; then
        local w1 w2
        w1=$(_ident_to_workdir "${paths[1]}" "${types[1]}")
        w2=$(_ident_to_workdir "${paths[2]}" "${types[2]}")
        local nt1=$([[ "${types[1]}" == file ]] && echo file || echo dir)
        local nt2=$([[ "${types[2]}" == file ]] && echo file || echo dir)
        if   [[ "$nt1" == file && "$nt2" == file ]]; then diff     "$w1" "$w2"
        elif [[ "$nt1" == dir  && "$nt2" == dir  ]]; then diff -qr  "$w1" "$w2"
        else
            printf 'identical: -d: cannot diff a plain file against a directory/archive\n' >&2
            _ident_cleanup; return 1
        fi
        _ident_cleanup; return
    fi

    # ── default cmp mode ─────────────────────────────────────────────────────
    local has_file=0 has_container=0
    for t in "${types[@]}"; do
        [[ "$t" == file ]] && has_file=1 || has_container=1
    done
    if (( has_file && has_container )); then
        printf 'identical: cannot mix plain files with directories/archives\n' >&2
        _ident_cleanup; return 1
    fi

    # all plain files: direct cmp against first
    if (( has_file )); then
        local all_same=1
        for (( i=2; i<=${#paths}; i++ )); do
            if ! cmp -s "${paths[1]}" "${paths[$i]}"; then
                printf 'Different: %s vs %s\n' "${paths[1]}" "${paths[$i]}"
                all_same=0
            fi
        done
        (( all_same )) && echo "Identical"
        _ident_cleanup; return
    fi

    # dirs/archives: normalize all to workdirs, compare all against first
    local -a workdirs=()
    for (( i=1; i<=${#paths}; i++ )); do
        workdirs+=("$(_ident_to_workdir "${paths[$i]}" "${types[$i]}")")
    done

    local ref="${workdirs[1]}" ref_name="${paths[1]}"
    local grand_diffs=0

    for (( i=2; i<=${#workdirs}; i++ )); do
        local other="${workdirs[$i]}" oname="${paths[$i]}"
        local diffs=0 only_ref=0 only_other=0 total=0

        while IFS= read -r rel; do
            (( total++ ))
            if [[ ! -e "$other/$rel" ]]; then
                printf 'Only in %s: %s\n' "$ref_name" "$rel"; (( only_ref++ ))
            elif ! cmp -s "$ref/$rel" "$other/$rel"; then
                printf 'Differ (%s vs %s): %s\n' "$ref_name" "$oname" "$rel"
                (( diffs++ ))
            fi
        done < <(find "$ref" -type f -printf '%P\n' | sort)

        while IFS= read -r rel; do
            [[ ! -e "$ref/$rel" ]] && {
                printf 'Only in %s: %s\n' "$oname" "$rel"; (( only_other++ ))
            }
        done < <(find "$other" -type f -printf '%P\n' | sort)

        (( grand_diffs += diffs + only_ref + only_other ))

        if (( diffs == 0 && only_ref == 0 && only_other == 0 )); then
            if (( ${#paths} > 2 )); then
                printf '%s and %s: identical (%d files)\n' "$ref_name" "$oname" "$total"
            else
                printf 'Identical (%d files)\n' "$total"
            fi
        fi
    done

    if (( grand_diffs == 0 && ${#paths} > 2 )); then
        printf 'All %d paths are identical\n' "${#paths}"
    fi

    _ident_cleanup
}
