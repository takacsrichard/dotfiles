# Compare N paths for identity.
# Usage: identical [MODE] [-rs N | -st C:P] [-star] <path1> <path2> [path3 ...]
#
# Modes (mutually exclusive; default = byte-for-byte via cmp):
#   -d       diff mode  : diff for files, diff -qr for dirs/archives; one diff per pair
#   -q       quick mode : filename + filesize only, no I/O
#
# Options:
#   -rs N        randomly sample N files from each archive byte-for-byte (2N total)
#   -st C:P      auto-sample: C% confident ≤P% of files differ  (e.g. -st 95:1)
#                samples N from each archive (2N total); both require dirs or archives
#   -star        for N>2: compare all paths against the first only (hub-and-spoke).
#   -exclude PAT suppress reporting of differences whose path contains PAT (case-sensitive
#                substring). Repeatable. Not supported with -d (will be cleared with warning).
#            Called "star" because in graph terms the first path is the hub
#            and every other is a spoke — N-1 comparisons instead of N(N-1)/2.
#            Default (without -star) is all-pairs: every combination is checked,
#            which gives a complete picture when no single canonical reference exists.
#
# Supported inputs: plain files, directories,
#   .tar / .tar.{gz,bz2,xz,zst} / .tgz, .zip, .7z
# N=2: -star has no effect (only one pair exists either way)

identical() {
    local mode=cmp rs_n=0 _st_arg='' star=0
    local -a _excludes=()

    while [[ $# -gt 0 && "$1" == -* ]]; do
        case "$1" in
            -d)       mode=diff;              shift ;;
            -q)       mode=quick;             shift ;;
            -rs)      rs_n="$2";              shift 2 ;;
            -st)      _st_arg="$2";           shift 2 ;;
            -star)    star=1;                 shift ;;
            -exclude) _excludes+=("$2");      shift 2 ;;
            --)       shift; break ;;
            *)        printf 'identical: unknown option %s\n' "$1" >&2; return 1 ;;
        esac
    done

    local -a paths=("$@")

    if (( ${#paths} < 2 )); then
        cat >&2 <<'USAGE'
Usage: identical [MODE] [-rs N | -st C:P] [-star] [-exclude PAT ...] <path1> <path2> [path3 ...]
  Modes:  (default) full cmp  |  -d diff (one diff per pair)  |  -q quick (size+name)
  -rs N          random-sample N files from each archive byte-for-byte (2N total)
  -st C:P        auto-sample: C% confident ≤P% of files differ  (e.g. -st 95:1)
  -star          N>2 only: compare all paths against the first (hub-and-spoke);
                 default is all-pairs: every combination, O(N²) but complete
  -exclude PAT   suppress differences whose path contains PAT (repeatable; not with -d)
  Types:  files, dirs, .tar[.gz|.bz2|.xz|.zst], .tgz, .zip, .7z
USAGE
        return 1
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
                   _ident_to_workdir _ident_internal_list \
                   _ident_detect_prefix _ident_stream \
                   _ident_excluded _ident_filter_excluded_list \
                   _ident_cleanup 2>/dev/null
    }

    # Return 0 (true) if path should be suppressed per -exclude patterns
    _ident_excluded() {
        local path="$1" pat
        for pat in "${_excludes[@]}"; do
            [[ "$path" == *"$pat"* ]] && return 0
        done
        return 1
    }

    # Filter a "size\tpath" list (stdin) removing excluded paths; pass-through if no excludes
    _ident_filter_excluded_list() {
        if (( ${#_excludes[@]} == 0 )); then cat; return; fi
        local line
        while IFS= read -r line; do
            local _fpath="${line#*$'\t'}"
            _ident_excluded "$_fpath" || printf '%s\n' "$line"
        done
    }

    # List internal file paths without prefix-stripping (one per line)
    _ident_internal_list() {
        local p="$1" type="$2"
        case "$type" in
            dir) find "$p" -type f -printf '%P\n' ;;
            tar) tar -tf "$p" 2>/dev/null | sed 's|^\./||' | grep -v '/$' ;;
            zip) unzip -l "$p" 2>/dev/null | awk '
                /^[[:space:]]*[0-9]+ +[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
                    line = $0
                    sub(/^[[:space:]]*[0-9]+[[:space:]]+[0-9-]+[[:space:]]+[0-9:]+[[:space:]]+/, "", line)
                    if (line != "" && line !~ /\/$/ && line !~ /^[0-9]+ file/) print line
                }' ;;
            7z)  7z l "$p" 2>/dev/null | awk '
                /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [^D]/ {
                    line = $0
                    sub(/^[0-9-]+ +[0-9:]+ +[^ ]+ +[0-9]+ +[0-9]+ +/, "", line)
                    if (line != "") print line
                }' ;;
        esac
    }

    # Read paths from stdin; print "prefix/" if all share one top-level component, else nothing
    _ident_detect_prefix() {
        awk '{
            idx = index($0, "/")
            p = (idx > 0) ? substr($0, 1, idx-1) : ""
            if (NR == 1) { pfx = p }
            else if (pfx != p) { pfx = ""; exit }
        }
        END { if (pfx != "") print pfx "/" }'
    }

    # Stream a single internal file from an archive/dir to stdout (no disk writes)
    _ident_stream() {
        local archive="$1" type="$2" internal_path="$3"
        case "$type" in
            dir) cat "$archive/$internal_path" 2>/dev/null ;;
            tar) tar -xf "$archive" --to-stdout "$internal_path" 2>/dev/null ;;
            zip) unzip -p "$archive" "$internal_path" 2>/dev/null ;;
            7z)  7z e "$archive" -so "$internal_path" 2>/dev/null ;;
        esac
    }

    # detect types for all paths
    local -a types=()
    local i
    for (( i=1; i<=${#paths}; i++ )); do
        types+=($(_ident_type "${paths[$i]}"))
    done

    # ── build pair list ───────────────────────────────────────────────────────
    # pair_lefts[k] and pair_rights[k] are indices into paths[] for pair k
    local -a pair_lefts=() pair_rights=()
    local _a _b
    if (( star || ${#paths} == 2 )); then
        # star / hub-and-spoke: all against first
        for (( _b=2; _b<=${#paths}; _b++ )); do
            pair_lefts+=(1); pair_rights+=($_b)
        done
    else
        # all-pairs: every combination
        for (( _a=1; _a<${#paths}; _a++ )); do
            for (( _b=_a+1; _b<=${#paths}; _b++ )); do
                pair_lefts+=($_a); pair_rights+=($_b)
            done
        done
    fi
    local npairs=${#pair_lefts}
    local show_pair_headers=$(( npairs > 1 ))

    # classify input types (used by -d and default cmp)
    local has_file=0 has_container=0
    for t in "${types[@]}"; do
        [[ "$t" == file ]] && has_file=1 || has_container=1
    done

    # ── -d + -exclude incompatibility ────────────────────────────────────────
    if [[ "$mode" == diff && ${#_excludes[@]} -gt 0 ]]; then
        printf 'identical: -d and -exclude are not reliably supported together; the run will proceed without -exclude.\n' >&2
        read -q "?Continue without -exclude? [y/N] " </dev/tty || { printf '\nAborted.\n' >&2; _ident_cleanup; return 1 }
        printf '\n'
        _excludes=()
    fi

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
        # cap at actual file count in first path
        local ref_count
        if [[ "${types[1]}" == dir ]]; then
            ref_count=$(find "${paths[1]}" -type f | wc -l)
        else
            ref_count=$(_ident_list "${paths[1]}" "${types[1]}" | wc -l)
        fi
        (( rs_n > ref_count )) && rs_n=$ref_count

        printf 'Statistical sample: %d files from each archive (%.0f%% confidence, ≤%s%% difference threshold)\n' \
               "$rs_n" "$st_conf" "$st_thresh"
        read -q "?Proceed? [y/N] " </dev/tty || { printf '\nAborted.\n' >&2; _ident_cleanup; return 1 }
        printf '\n'
    fi

    # ── random-sample / statistical-sample mode ───────────────────────────────
    if (( rs_n > 0 )); then
        for (( i=1; i<=${#types}; i++ )); do
            if [[ "${types[$i]}" == file ]]; then
                printf 'identical: -rs/-st requires dirs or archives, not plain files\n' >&2
                _ident_cleanup; return 1
            fi
        done

        # Build internal path lists and per-archive prefix — no extraction, no disk writes
        local _rs_raw _rs_pfx
        local -a _rs_lists=() _rs_pfxs=()
        for (( i=1; i<=${#paths}; i++ )); do
            _rs_raw=$(_ident_internal_list "${paths[$i]}" "${types[$i]}")
            _rs_lists+=("$_rs_raw")
            _rs_pfx=$(printf '%s\n' "$_rs_raw" | _ident_detect_prefix)
            _rs_pfxs+=("$_rs_pfx")
        done

        local grand_diffs=0 grand_only=0 grand_checked=0
        local pk
        for (( pk=1; pk<=npairs; pk++ )); do
            local ia=${pair_lefts[$pk]} ib=${pair_rights[$pk]}
            local nA="${paths[$ia]}" nB="${paths[$ib]}"
            local pfxA="${_rs_pfxs[$ia]}" pfxB="${_rs_pfxs[$ib]}"
            local pair_diffs=0 pair_only_a=0 pair_only_b=0 pair_checked=0

            (( show_pair_headers )) && printf '── %s vs %s ──\n' "$nA" "$nB"

            # Build lookup set of normalized (prefix-stripped) paths present in B
            local -A _rs_b_set=()
            local _rs_entry=''
            while IFS= read -r _rs_entry; do
                [[ -z "$_rs_entry" ]] && continue
                _rs_b_set[${_rs_entry#$pfxB}]=1
            done <<< "${_rs_lists[$ib]}"

            # Pass 1: sample N from A — catches content diffs and files only in A
            while IFS= read -r _rs_entry; do
                [[ -z "$_rs_entry" ]] && continue
                local _rs_rel="${_rs_entry#$pfxA}"
                (( pair_checked++ ))
                if [[ -z "${_rs_b_set[$_rs_rel]}" ]]; then
                    if ! _ident_excluded "$_rs_rel"; then
                        printf 'Only in %s (not %s): %s\n' "$nA" "$nB" "$_rs_rel"
                        (( pair_only_a++ ))
                    fi
                elif ! cmp -s \
                        <(_ident_stream "${paths[$ia]}" "${types[$ia]}" "$_rs_entry") \
                        <(_ident_stream "${paths[$ib]}" "${types[$ib]}" "${pfxB}${_rs_rel}"); then
                    if ! _ident_excluded "$_rs_rel"; then
                        printf 'Differ (%s vs %s): %s\n' "$nA" "$nB" "$_rs_rel"
                        (( pair_diffs++ ))
                    fi
                fi
            done < <(printf '%s\n' "${_rs_lists[$ia]}" | grep -v '^$' | shuf -n "$rs_n")

            # Build lookup set of normalized paths present in A (for pass 2)
            local -A _rs_a_set=()
            while IFS= read -r _rs_entry; do
                [[ -z "$_rs_entry" ]] && continue
                _rs_a_set[${_rs_entry#$pfxA}]=1
            done <<< "${_rs_lists[$ia]}"

            # Pass 2: sample N from B — catches files only in B (deletions from A's perspective)
            # Content equality for files in both is already covered by pass 1.
            while IFS= read -r _rs_entry; do
                [[ -z "$_rs_entry" ]] && continue
                local _rs_rel="${_rs_entry#$pfxB}"
                if [[ -z "${_rs_a_set[$_rs_rel]}" ]]; then
                    if ! _ident_excluded "$_rs_rel"; then
                        printf 'Only in %s (not %s): %s\n' "$nB" "$nA" "$_rs_rel"
                        (( pair_only_b++ ))
                    fi
                fi
            done < <(printf '%s\n' "${_rs_lists[$ib]}" | grep -v '^$' | shuf -n "$rs_n")

            if (( pair_diffs == 0 && pair_only_a == 0 && pair_only_b == 0 )); then
                printf 'All %d sampled files are identical\n' "$pair_checked"
            else
                printf '%d/%d differ, %d only in %s, %d only in %s\n' \
                       "$pair_diffs" "$pair_checked" "$pair_only_a" "$nA" "$pair_only_b" "$nB"
            fi
            (( grand_diffs += pair_diffs ))
            (( grand_only  += pair_only_a + pair_only_b ))
            (( grand_checked += pair_checked ))
        done

        if (( show_pair_headers )); then
            if (( grand_diffs == 0 && grand_only == 0 )); then
                printf 'All %d pairs identical\n' "$npairs"
            else
                printf 'Summary: %d/%d total differ, %d only in one side across %d pairs\n' \
                       "$grand_diffs" "$grand_checked" "$grand_only" "$npairs"
            fi
        fi
        _ident_cleanup; return
    fi

    # ── quick mode (-q) ───────────────────────────────────────────────────────
    if [[ "$mode" == quick ]]; then
        # pre-compute all lists to avoid redundant work (each path may appear in multiple pairs)
        local -a _qlists=()
        for (( i=1; i<=${#paths}; i++ )); do
            _qlists+=("$(_ident_list "${paths[$i]}" "${types[$i]}")")
        done

        local any_diff=0
        local pk
        for (( pk=1; pk<=npairs; pk++ )); do
            local ia=${pair_lefts[$pk]} ib=${pair_rights[$pk]}
            local out ret
            out=$(diff <(printf '%s\n' "${_qlists[$ia]}" | _ident_filter_excluded_list) \
                       <(printf '%s\n' "${_qlists[$ib]}" | _ident_filter_excluded_list))
            ret=$?
            if (( ret != 0 )); then
                any_diff=1
                (( show_pair_headers )) && printf '── %s vs %s ──\n' "${paths[$ia]}" "${paths[$ib]}"
                printf '%s\n' "$out" | awk -F'\t' -v a="${paths[$ia]}" -v b="${paths[$ib]}" '
                    /^</ { printf "Only in %s: %s (%s bytes)\n", a, $2, substr($1,3) }
                    /^>/ { printf "Only in %s: %s (%s bytes)\n", b, $2, substr($1,3) }
                '
            elif (( show_pair_headers )); then
                printf '%s and %s: identical (metadata)\n' "${paths[$ia]}" "${paths[$ib]}"
            fi
        done
        if (( !any_diff )); then
            if   (( ${#paths} == 2 )); then echo "Identical (metadata)"
            else printf 'All %d paths identical (metadata)\n' "${#paths}"; fi
        fi
        _ident_cleanup; return
    fi

    # ── diff mode (-d) ───────────────────────────────────────────────────────
    if [[ "$mode" == diff ]]; then
        if (( has_file && has_container )); then
            printf 'identical: cannot mix plain files with directories/archives\n' >&2
            _ident_cleanup; return 1
        fi
        # Warn before extracting if total input size exceeds 5 GiB
        local _d_total=0 _d_sz _d_gib
        for (( i=1; i<=${#paths}; i++ )); do
            if [[ "${types[$i]}" == dir ]]; then
                _d_sz=$(du -sb "${paths[$i]}" 2>/dev/null | awk '{print $1}')
            else
                _d_sz=$(stat -c '%s' "${paths[$i]}" 2>/dev/null)
            fi
            (( _d_total += ${_d_sz:-0} ))
        done
        if (( _d_total > 5 * 1024 * 1024 * 1024 )); then
            _d_gib=$(awk "BEGIN{printf \"%.1f\", $_d_total/1073741824}")
            printf 'Warning: inputs total %s GiB — -d will extract everything to temporary disk.\n' "$_d_gib" >&2
            read -q "?Proceed? [y/N] " </dev/tty || { printf '\nAborted.\n' >&2; _ident_cleanup; return 1 }
            printf '\n'
        fi
        local -a workdirs=()
        for (( i=1; i<=${#paths}; i++ )); do
            workdirs+=("$(_ident_to_workdir "${paths[$i]}" "${types[$i]}")")
        done
        local pk
        for (( pk=1; pk<=npairs; pk++ )); do
            local ia=${pair_lefts[$pk]} ib=${pair_rights[$pk]}
            local wA="${workdirs[$ia]}" wB="${workdirs[$ib]}"
            local ntA=$([[ "${types[$ia]}" == file ]] && echo file || echo dir)
            local ntB=$([[ "${types[$ib]}" == file ]] && echo file || echo dir)
            if (( show_pair_headers )); then
                printf '── %s vs %s ──\n' "${paths[$ia]}" "${paths[$ib]}"
            fi
            if   [[ "$ntA" == file && "$ntB" == file ]]; then diff     "$wA" "$wB"
            elif [[ "$ntA" == dir  && "$ntB" == dir  ]]; then diff -qr  "$wA" "$wB"
            else
                printf 'identical: -d: cannot diff a plain file against a directory/archive\n' >&2
                _ident_cleanup; return 1
            fi
        done
        _ident_cleanup; return
    fi

    # ── default cmp mode ─────────────────────────────────────────────────────
    if (( has_file && has_container )); then
        printf 'identical: cannot mix plain files with directories/archives\n' >&2
        _ident_cleanup; return 1
    fi

    # all plain files: cmp each pair
    if (( has_file )); then
        local all_same=1
        local pk
        for (( pk=1; pk<=npairs; pk++ )); do
            local ia=${pair_lefts[$pk]} ib=${pair_rights[$pk]}
            if ! cmp -s "${paths[$ia]}" "${paths[$ib]}"; then
                printf 'Different: %s vs %s\n' "${paths[$ia]}" "${paths[$ib]}"
                all_same=0
            fi
        done
        (( all_same )) && echo "Identical"
        _ident_cleanup; return
    fi

    # dirs/archives: normalize all to workdirs, compare each pair
    local -a workdirs=()
    for (( i=1; i<=${#paths}; i++ )); do
        workdirs+=("$(_ident_to_workdir "${paths[$i]}" "${types[$i]}")")
    done

    local grand_diffs=0
    local pk
    for (( pk=1; pk<=npairs; pk++ )); do
        local ia=${pair_lefts[$pk]} ib=${pair_rights[$pk]}
        local wA="${workdirs[$ia]}" wB="${workdirs[$ib]}"
        local nA="${paths[$ia]}"    nB="${paths[$ib]}"
        local diffs=0 only_a=0 only_b=0 total=0

        while IFS= read -r rel; do
            (( total++ ))
            if [[ ! -e "$wB/$rel" ]]; then
                if ! _ident_excluded "$rel"; then
                    printf 'Only in %s: %s\n' "$nA" "$rel"; (( only_a++ ))
                fi
            elif ! cmp -s "$wA/$rel" "$wB/$rel"; then
                if ! _ident_excluded "$rel"; then
                    printf 'Differ (%s vs %s): %s\n' "$nA" "$nB" "$rel"
                    (( diffs++ ))
                fi
            fi
        done < <(find "$wA" -type f -printf '%P\n' | sort)

        while IFS= read -r rel; do
            if [[ ! -e "$wA/$rel" ]] && ! _ident_excluded "$rel"; then
                printf 'Only in %s: %s\n' "$nB" "$rel"; (( only_b++ ))
            fi
        done < <(find "$wB" -type f -printf '%P\n' | sort)

        (( grand_diffs += diffs + only_a + only_b ))

        if (( diffs == 0 && only_a == 0 && only_b == 0 )); then
            if   (( show_pair_headers )); then
                printf '%s and %s: identical (%d files)\n' "$nA" "$nB" "$total"
            else
                printf 'Identical (%d files)\n' "$total"
            fi
        fi
    done

    if (( grand_diffs == 0 && show_pair_headers )); then
        printf 'All %d paths are identical\n' "${#paths}"
    fi

    _ident_cleanup
}
