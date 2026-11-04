#!/usr/bin/env bash
#
# smartctl-test: triggers a short self-test on the nvme drive, waits for it
# to finish, then dumps the full report as json for the dashboard to read.

set -uo pipefail

DEV=/dev/nvme0n1
OUT=/home/richard/dashboard/data/smartctl.json

smartctl -t short "$DEV" >/dev/null

# nvme short self-tests usually finish within ~2 minutes - poll until done
for _ in $(seq 1 60); do
    sleep 10
    smartctl -l selftest "$DEV" | grep -q "No self-test in progress" && break
done

mkdir -p "$(dirname "$OUT")"
smartctl -a -j "$DEV" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
