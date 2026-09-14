alias wuvpnon="sudo openconnect --protocol=gp -b vpn.wu.ac.at"
alias wuvpnoff="sudo pkill openconnect"

# CIDRs that bypass all VPN interfaces and go via the regular connection instead.
# 137.208.0.0/16  = WU AS1776 (wu.ac.at and all subdomains)
# 99.84.91.0/24   = canvas.wu.ac.at → wu-vanity.instructure.com (CloudFront CDN range A)
# 65.9.130.0/24   = canvas.wu.ac.at → wu-vanity.instructure.com (CloudFront CDN range B)
# 193.22.104.0/23 = willhaben.at AS34798 (willhaben internet service GmbH)
_VPN_BYPASS=(
    "137.208.0.0/16"
    "99.84.91.0/24"
    "65.9.130.0/24"
    "193.22.104.0/23"
)

_vpn_bypass_add() {
    local iface="${1:-atvpn}"
    for cidr in "${_VPN_BYPASS[@]}"; do
        sudo ip rule add to "$cidr" table main priority 100 2>/dev/null
    done
    # Revert wg-quick's DNS override so systemd-resolved uses the network's DNS
    # instead of routing DNS queries through the VPN tunnel.
    sudo resolvectl revert "$iface" 2>/dev/null
}

_vpn_bypass_del() {
    for cidr in "${_VPN_BYPASS[@]}"; do
        sudo ip rule del to "$cidr" table main priority 100 2>/dev/null
    done
}

vpnon() {
    local flag="${1:--a}"
    local conf=""
    local pf=false

    case "$flag" in
        -a)   conf="atvpn" ;;
        -apf) conf="atvpn_pf"; pf=true ;;
        -h)   conf="huvpn" ;;
        -hpf) conf="huvpn_pf"; pf=true ;;
        *)
            echo "Usage: vpnon [-a|-apf|-h|-hpf]"
            echo "  -a    Austria VPN"
            echo "  -apf  Austria VPN with port forwarding"
            echo "  -h    Hungary VPN"
            echo "  -hpf  Hungary VPN with port forwarding"
            return 1
            ;;
    esac

    local active_vpn
    for active_vpn in atvpn atvpn_pf huvpn huvpn_pf; do
        if systemctl is-active --quiet wg-quick-$active_vpn 2>/dev/null; then
            echo "Already connected to $active_vpn. Run vpnoff first." >&2
            return 1
        fi
    done

    echo "Connecting to $conf..."
    sudo systemctl start wg-quick-$conf || { echo "Failed to connect to $conf." >&2; return 1; }
    _vpn_bypass_add "$conf"
    echo "Connected to $conf."
    if [[ "$pf" == true ]]; then
        echo "Public port: $(getpport)"
    fi
    sleep 3 && myip
}

vpnoff() {
    local active=()
    local svc
    for svc in atvpn atvpn_pf huvpn huvpn_pf; do
        if systemctl is-active --quiet wg-quick-$svc 2>/dev/null; then
            active+=($svc)
        fi
    done

    if (( ${#active[@]} == 0 )); then
        echo "No WireGuard VPN is active."
        return 0
    fi

    for svc in "${active[@]}"; do
        echo "Disconnecting $svc..."
        _vpn_bypass_del
        sudo systemctl stop wg-quick-$svc
    done
    sleep 3 && myip
}

editvpn() {
    local flag="$1"
    local conf=""

    case "$flag" in
        -a)   conf="atvpn" ;;
        -apf) conf="atvpn_pf" ;;
        -h)   conf="huvpn" ;;
        -hpf) conf="huvpn_pf" ;;
        *)
            echo "Usage: editvpn [-a|-apf|-h|-hpf]"
            echo "  -a    Austria VPN"
            echo "  -apf  Austria VPN with port forwarding"
            echo "  -h    Hungary VPN"
            echo "  -hpf  Hungary VPN with port forwarding"
            return 1
            ;;
    esac

    sudo nvim /etc/wireguard/$conf.conf
}

# Display current public NAT-PMP port (requires an active pf VPN connection)
getpport() {
    local port="$(natpmpc -a 1 0 tcp 60 -g 10.2.0.1 2>/dev/null \
        | grep -oP 'Mapped public port \K[0-9]+' \
        | head -n1)"

    if [[ -n "$port" ]]; then
        echo "$port"
    else
        echo "Failed to get public port" >&2
        return 1
    fi
}
