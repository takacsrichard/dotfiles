#!/usr/bin/env bash
#
# thermal-guard: caps CPU max frequency to 2.2GHz when CPU (k10temp Tctl) or
# motherboard (acpitz) temperature exceeds 85C, and releases the cap back to
# each core's full cpuinfo_max_freq once temp drops below 65C (hysteresis).

set -uo pipefail

HIGH_TEMP=80
LOW_TEMP=60
CHECK_INTERVAL=30
CAP_FREQ_KHZ=2200000
TAG=thermal-guard

CPUFREQ_DIRS=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq)

log() { echo "$1" | systemd-cat -t "$TAG" -p "${2:-info}"; }

declare -A CORE_MAX_FREQ
for dir in "${CPUFREQ_DIRS[@]}"; do
    CORE_MAX_FREQ["$dir"]=$(cat "$dir/cpuinfo_max_freq" 2>/dev/null || echo 0)
done

throttled=0

apply_cap() {
    local capped=$1
    for dir in "${CPUFREQ_DIRS[@]}"; do
        local target
        if [[ $capped -eq 1 ]]; then
            target=$CAP_FREQ_KHZ
        else
            target=${CORE_MAX_FREQ["$dir"]}
        fi
        [[ $target -gt 0 ]] && echo "$target" > "$dir/scaling_max_freq" 2>/dev/null
    done
}

get_max_temp() {
    sensors -j 2>/dev/null | jq -r '
        [.["k10temp-pci-00c3"].Tctl.temp1_input?,
         .["acpitz-acpi-0"].temp1.temp1_input?]
        | map(select(type == "number")) | max // empty'
}

is_above() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a>b)}'; }
is_below() { awk -v a="$1" -v b="$2" 'BEGIN{exit !(a<b)}'; }

restore_on_exit() {
    log "thermal-guard stopping: restoring full CPU frequency"
    apply_cap 0
    exit 0
}
trap restore_on_exit SIGTERM SIGINT

log "thermal-guard started: high=${HIGH_TEMP}C low=${LOW_TEMP}C cap=$((CAP_FREQ_KHZ/1000))MHz interval=${CHECK_INTERVAL}s"

while true; do
    temp=$(get_max_temp)

    if [[ -n "$temp" ]]; then
        if [[ $throttled -eq 0 ]] && is_above "$temp" "$HIGH_TEMP"; then
            throttled=1
            apply_cap 1
            log "temp ${temp}C > ${HIGH_TEMP}C -> capping CPU to $((CAP_FREQ_KHZ/1000))MHz" warning
        elif [[ $throttled -eq 1 ]] && is_below "$temp" "$LOW_TEMP"; then
            throttled=0
            apply_cap 0
            log "temp ${temp}C < ${LOW_TEMP}C -> restoring full CPU frequency"
        fi
    fi

    sleep "$CHECK_INTERVAL"
done
