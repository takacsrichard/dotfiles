#!/usr/bin/env bash
#
# btrfs-heatmap: generates a chunk heatmap png for / and keeps only the
# latest copy around under a stable name for the dashboard to serve.

set -uo pipefail

OUTDIR=/home/richard/dashboard/data

mkdir -p "$OUTDIR"
cd "$OUTDIR"

rm -f fsid_*_chunks_at_*.png

btrfs-heatmap / --sort virtual

latest=$(ls -t fsid_*_chunks_at_*.png 2>/dev/null | head -n1)
[[ -n "$latest" ]] && mv "$latest" btrfs-heatmap.png
