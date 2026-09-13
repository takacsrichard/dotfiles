# Check subset relationships between two directories or tar archives.
# Usage: is-subset [-q] <dir|tar> <dir|tar>
#
# Supported tar formats: .tar  .tar.gz  .tar.bz2  .tar.xz  .tar.zst  .tgz
#
# Default: sha256 content comparison (single streaming pass — no disk writes)
#   -q    quick mode: path + filesize only, no I/O
#
# Reports:
#   A ⊆ B  — every file in A exists in B at the same relative path (and matches)
#   B ⊆ A  — every file in B exists in A at the same relative path (and matches)
#   identical — both hold

is-subset() {
    local quick=0
    [[ "$1" == -q ]] && { quick=1; shift }

    if (( $# != 2 )); then
        printf 'Usage: is-subset [-q] <dir|tar> <dir|tar>\n' >&2
        return 1
    fi

    local srcA="$1" srcB="$2"

    # ── type detection (inline, no subshell) ──────────────────────────────────
    local typeA typeB pl
    pl="${srcA:l}"
    if   [[ -d "$srcA" ]];                                            then typeA=dir
    elif [[ "$pl" =~ \.(tar(\.(gz|bz2|xz|zst))?|tgz)$ ]];           then typeA=tar
    else printf 'is-subset: %s: not a directory or tar archive\n' "$srcA" >&2; return 1; fi
    pl="${srcB:l}"
    if   [[ -d "$srcB" ]];                                            then typeB=dir
    elif [[ "$pl" =~ \.(tar(\.(gz|bz2|xz|zst))?|tgz)$ ]];           then typeB=tar
    else printf 'is-subset: %s: not a directory or tar archive\n' "$srcB" >&2; return 1; fi

    # ── _isub_entries: output "value\trelpath" for each regular file ──────────
    # quick=1 → value is file size  (no content I/O)
    # quick=0 → value is sha256     (single streaming pass through all content)
    # $3 must be passed explicitly because local vars are not subshell-visible
    _isub_entries() {
        local src="$1" type="$2" q="${3:-0}"
        if (( q )); then
            case "$type" in
                dir)
                    find "$src" -type f -printf '%s\t%P\n'
                    ;;
                tar)
                    tar -tvf "$src" 2>/dev/null | awk '
                        /^-/ {
                            sz=$3; path=$NF
                            sub(/^\.\//, "", path)
                            if (sz != "" && path != "" && path !~ /\/$/)
                                print sz "\t" path
                        }'
                    ;;
            esac
        else
            python3 - "$type" "$src" <<'PYEOF'
import sys, hashlib

def sha256_fh(fh):
    h = hashlib.sha256()
    while chunk := fh.read(1 << 20):
        h.update(chunk)
    return h.hexdigest()

mode, src = sys.argv[1], sys.argv[2]

if mode == 'dir':
    import os
    for root, dirs, files in os.walk(src):
        dirs.sort()
        for name in sorted(files):
            path = os.path.join(root, name)
            rel  = os.path.relpath(path, src)
            try:
                with open(path, 'rb') as fh:
                    print(sha256_fh(fh) + '\t' + rel)
            except OSError:
                pass

elif mode == 'tar':
    import tarfile
    with tarfile.open(src) as tf:
        for m in tf.getmembers():
            if not m.isfile():
                continue
            fh = tf.extractfile(m)
            if fh is None:
                continue
            rel = m.name.lstrip('./')
            print(sha256_fh(fh) + '\t' + rel)
PYEOF
        fi
    }

    _isub_cleanup() {
        unfunction _isub_entries _isub_cleanup 2>/dev/null
    }

    (( quick )) && printf '(quick mode: path + size only)\n\n'

    # ── build maps: rel → (size or sha256) ───────────────────────────────────
    typeset -A map_a map_b
    local _k _v
    while IFS=$'\t' read -r _v _k; do
        [[ -n "$_k" && -n "$_v" ]] && map_a[$_k]=$_v
    done < <(_isub_entries "$srcA" "$typeA" "$quick")
    while IFS=$'\t' read -r _v _k; do
        [[ -n "$_k" && -n "$_v" ]] && map_b[$_k]=$_v
    done < <(_isub_entries "$srcB" "$typeB" "$quick")

    # ── A ⊆ B ─────────────────────────────────────────────────────────────────
    local a_total=0 a_matched=0 a_missing=0 a_differ=0 rel
    for rel in ${(k)map_a}; do
        (( ++a_total ))
        if [[ -z "${map_b[$rel]}" ]]; then
            (( ++a_missing ))
        elif [[ "${map_a[$rel]}" == "${map_b[$rel]}" ]]; then
            (( ++a_matched ))
        else
            (( ++a_differ ))
        fi
    done

    # ── B ⊆ A ─────────────────────────────────────────────────────────────────
    local b_total=0 b_matched=0 b_missing=0 b_differ=0
    for rel in ${(k)map_b}; do
        (( ++b_total ))
        if [[ -z "${map_a[$rel]}" ]]; then
            (( ++b_missing ))
        elif [[ "${map_b[$rel]}" == "${map_a[$rel]}" ]]; then
            (( ++b_matched ))
        else
            (( ++b_differ ))
        fi
    done

    _isub_cleanup

    # ── output ────────────────────────────────────────────────────────────────
    local a_sub b_sub
    (( a_missing == 0 && a_differ == 0 )) && a_sub=yes || a_sub=no
    (( b_missing == 0 && b_differ == 0 )) && b_sub=yes || b_sub=no

    printf 'A: %s  [%s, %d files]\n' "$srcA" "$typeA" "$a_total"
    printf 'B: %s  [%s, %d files]\n' "$srcB" "$typeB" "$b_total"
    printf '\n'

    printf 'A ⊆ B:  %s' "$a_sub"
    if [[ "$a_sub" == no ]]; then
        printf '  (%d/%d matched' "$a_matched" "$a_total"
        (( a_missing > 0 )) && printf ', %d missing' "$a_missing"
        (( a_differ  > 0 )) && printf ', %d differ'  "$a_differ"
        printf ')'
    else
        printf '  (%d/%d matched)' "$a_matched" "$a_total"
    fi
    printf '\n'

    printf 'B ⊆ A:  %s' "$b_sub"
    if [[ "$b_sub" == no ]]; then
        printf '  (%d/%d matched' "$b_matched" "$b_total"
        (( b_missing > 0 )) && printf ', %d missing' "$b_missing"
        (( b_differ  > 0 )) && printf ', %d differ'  "$b_differ"
        printf ')'
    else
        printf '  (%d/%d matched)' "$b_matched" "$b_total"
    fi
    printf '\n'
    printf '\n'

    if [[ "$a_sub" == yes && "$b_sub" == yes ]]; then
        printf 'identical: yes\n'
    else
        printf 'identical: no\n'
    fi
}
