# Stats for systemd services I hand-declare in nix-config (not distro/module
# defaults). darkstat/home-manager expand to multiple unit names at build
# time, so patterns here use globs instead of a literal list; pass unit
# names/globs as args to override. Discovery of exact matches:
#   systemctl list-units --all --type=service --plain --no-legend <patterns>
svcstats() {
    emulate -L zsh
    setopt local_options pipefail

    local -a patterns
    if (( $# )); then
        patterns=("$@")
    else
        patterns=(thermal-guard.service 'darkstat-*.service' wg-quick-atvpn.service)
    fi

    local -a units
    units=(${(f)"$(systemctl list-units --all --plain --no-legend --type=service "${patterns[@]}" 2>/dev/null | awk '{print $1}')"})

    if (( ! ${#units[@]} )); then
        print "svcstats: no matching units for: ${patterns[*]}"
        return 1
    fi

    local -a headers=(NAME LOADED ACTIVE PID MEM PEAK "CPU%" IP-IN IP-OUT IO-IN IO-OUT)
    local sep=$'\x1f'
    local -a rows=()

    # fraction of the whole machine's CPU capacity (all cores), not of one core
    local cores=$(nproc 2>/dev/null)
    (( cores )) || cores=1

    for u in "${units[@]}"; do
        local -a lines=("${(@f)$(systemctl show "$u" -p LoadState,ActiveState,SubState,MainPID,MemoryCurrent,MemoryPeak,CPUUsageNSec,ActiveEnterTimestamp,IPIngressBytes,IPEgressBytes,IOReadBytes,IOWriteBytes)}")

        local -A p
        for line in "${lines[@]}"; do
            local k="${line%%=*}" v="${line#*=}"
            p[$k]="$v"
        done

        local active="${p[ActiveState]}/${p[SubState]}"
        local pid="${p[MainPID]:-0}"
        [[ "$pid" == 0 ]] && pid="-"

        # CPU time consumed, as a percent of total machine capacity (all
        # cores) available since the unit started: cpu_ms / (cores * wall_ms) * 100.
        local cpu_ms=$(( ${p[CPUUsageNSec]:-0} / 1000000 ))
        local rate="n/a"
        if [[ "${p[ActiveState]}" == "active" && -n "${p[ActiveEnterTimestamp]}" ]]; then
            local start_epoch=$(LC_ALL=C date -d "${p[ActiveEnterTimestamp]}" +%s 2>/dev/null)
            if [[ -n "$start_epoch" ]]; then
                local delta=$(( $(date +%s) - start_epoch ))
                (( delta > 0 )) && rate=$(awk -v ms="$cpu_ms" -v s="$delta" -v c="$cores" 'BEGIN{printf "%.4f", (ms/(c*s*1000))*100}')
            fi
        fi

        # IPAccounting/IOAccounting aren't enabled on every unit; systemd
        # reports "[not set]" rather than 0 when they're off.
        local memcur="${p[MemoryCurrent]}" mempeak="${p[MemoryPeak]}"
        local ipin="${p[IPIngressBytes]}" ipout="${p[IPEgressBytes]}"
        local ioin="${p[IOReadBytes]}" ioout="${p[IOWriteBytes]}"
        [[ "$memcur" == "[not set]" ]] && memcur=0
        [[ "$mempeak" == "[not set]" ]] && mempeak=0
        [[ "$ipin" == "[not set]" ]] && ipin="-"
        [[ "$ipout" == "[not set]" ]] && ipout="-"
        [[ "$ioin" == "[not set]" ]] && ioin="-"
        [[ "$ioout" == "[not set]" ]] && ioout="-"

        local memcur_h=$(LC_ALL=C numfmt --to=iec "$memcur" 2>/dev/null)
        local mempeak_h=$(LC_ALL=C numfmt --to=iec "$mempeak" 2>/dev/null)
        local ipin_h=$([[ "$ipin" == "-" ]] && echo "-" || LC_ALL=C numfmt --to=iec "$ipin")
        local ipout_h=$([[ "$ipout" == "-" ]] && echo "-" || LC_ALL=C numfmt --to=iec "$ipout")
        local ioin_h=$([[ "$ioin" == "-" ]] && echo "-" || LC_ALL=C numfmt --to=iec "$ioin")
        local ioout_h=$([[ "$ioout" == "-" ]] && echo "-" || LC_ALL=C numfmt --to=iec "$ioout")

        rows+=("${u}${sep}${p[LoadState]}${sep}${active}${sep}${pid}${sep}${memcur_h}${sep}${mempeak_h}${sep}${rate}${sep}${ipin_h}${sep}${ipout_h}${sep}${ioin_h}${sep}${ioout_h}")
    done

    # column widths = longest value seen (header or data), 1 space padding each side
    local -a widths=()
    for i in {1..${#headers[@]}}; do
        widths+=(${#headers[i]})
    done
    for row in "${rows[@]}"; do
        local -a fields=("${(@ps:\x1f:)row}")
        for i in {1..${#fields[@]}}; do
            (( ${#fields[i]} > widths[i] )) && widths[i]=${#fields[i]}
        done
    done

    local top="┌" hsep="├" bot="└"
    for i in {1..${#widths[@]}}; do
        local dash=$(printf '─%.0s' {1..$((widths[i]+2))})
        top+="$dash"
        hsep+="$dash"
        bot+="$dash"
        if (( i < ${#widths[@]} )); then
            top+="┬"
            hsep+="┼"
            bot+="┴"
        fi
    done
    top+="┐"
    hsep+="┤"
    bot+="┘"

    local fmt="│"
    for i in {1..${#widths[@]}}; do
        if (( i <= 3 )); then
            fmt+=" %-${widths[i]}s │"
        else
            fmt+=" %${widths[i]}s │"
        fi
    done
    fmt+=$'\n'

    print -r -- "$top"
    printf "$fmt" "${headers[@]}"
    print -r -- "$hsep"
    for row in "${rows[@]}"; do
        local -a fields=("${(@ps:\x1f:)row}")
        printf "$fmt" "${fields[@]}"
    done
    print -r -- "$bot"
}

# Battery stats from sysfs (this hardware exposes charge_* in uAh + current_now
# in uA, not the energy_*/power_now uWh/uW pair some laptops use instead).
battinfo() {
    emulate -L zsh
    setopt local_options

    local dir="${1:-/sys/class/power_supply/BAT0}"
    if [[ ! -d "$dir" ]]; then
        print "battinfo: no such battery dir: $dir" >&2
        return 1
    fi

    local _read
    _read() { command cat "$dir/$1" 2>/dev/null }

    local pct=$(_read capacity)
    local bstatus=$(_read status)
    local charge_now=$(_read charge_now)
    local charge_full=$(_read charge_full)
    local charge_full_design=$(_read charge_full_design)
    local current_now=$(_read current_now)
    local voltage_now=$(_read voltage_now)
    local model=$(_read model_name)
    local cycles=$(_read cycle_count)

    if [[ -z "$charge_now" || -z "$charge_full" || -z "$charge_full_design" ]]; then
        print "battinfo: missing charge_* attributes under $dir" >&2
        return 1
    fi

    # uAh -> Ah for display
    local now_ah=$(awk -v v="$charge_now" 'BEGIN{printf "%.3f", v/1e6}')
    local full_ah=$(awk -v v="$charge_full" 'BEGIN{printf "%.3f", v/1e6}')
    local design_ah=$(awk -v v="$charge_full_design" 'BEGIN{printf "%.3f", v/1e6}')

    local health=$(awk -v f="$charge_full" -v d="$charge_full_design" 'BEGIN{printf "%.1f", (f/d)*100}')
    local degradation=$(awk -v h="$health" 'BEGIN{printf "%.1f", 100-h}')

    local watts="n/a" rate_desc="n/a"
    if [[ -n "$current_now" && -n "$voltage_now" && "$current_now" != 0 ]]; then
        watts=$(awk -v i="$current_now" -v v="$voltage_now" 'BEGIN{printf "%.2f", (i/1e6)*(v/1e6)}')
        case "$bstatus" in
            Discharging) rate_desc="-${watts}W" ;;
            Charging)    rate_desc="+${watts}W" ;;
            *)            rate_desc="${watts}W" ;;
        esac
    fi

    local time_desc="n/a"
    if [[ -n "$current_now" && "$current_now" != 0 ]]; then
        case "$bstatus" in
            Discharging)
                local target=$(awk -v f="$charge_full" 'BEGIN{printf "%.0f", f*0.10}')
                if (( charge_now > target )); then
                    local hrs=$(awk -v c="$charge_now" -v t="$target" -v i="$current_now" 'BEGIN{printf "%.2f", (c-t)/i}')
                    time_desc="${hrs}h to 10%"
                else
                    local hrs=$(awk -v c="$charge_now" -v i="$current_now" 'BEGIN{printf "%.2f", c/i}')
                    time_desc="already <=10%, ${hrs}h to empty"
                fi
                ;;
            Charging)
                local hrs=$(awk -v f="$charge_full" -v c="$charge_now" -v i="$current_now" 'BEGIN{printf "%.2f", (f-c)/i}')
                time_desc="${hrs}h to full"
                ;;
            *)
                time_desc="n/a (status: $bstatus)"
                ;;
        esac
    fi

    print -r -- "Battery:        ${model:-unknown}"
    print -r -- "Status:         ${bstatus:-unknown}"
    print -r -- "Charge:         ${pct}%  (${now_ah} Ah / ${full_ah} Ah max)"
    print -r -- "Rated capacity: ${design_ah} Ah (design)"
    print -r -- "Max capacity:   ${full_ah} Ah (current full)"
    print -r -- "Health:         ${health}%  (degradation: ${degradation}%)"
    print -r -- "Rate:           ${rate_desc}"
    print -r -- "Estimate:       ${time_desc}"
    [[ -n "$cycles" ]] && print -r -- "Cycles:         ${cycles}"
}
