{ pkgs, lib, ... }:
let
  # No NixOS module ships for darkstat, so each instance's systemd unit is
  # written by hand below; this just avoids repeating it per interface.
  # Each darkstat starts as root to open the raw capture socket, then drops
  # to --user/--chroot itself. --import/--export persist the host table
  # across restarts, --daylog keeps a running daily rx/tx/pkt CSV.
  mkDarkstat = { name, interface, port, unitExtra }: {
    systemd.tmpfiles.rules = [
      "d /var/lib/darkstat-${name} 0750 darkstat darkstat -"
    ];
    systemd.services."darkstat-${name}" = unitExtra // {
      description = "darkstat network traffic analyzer (${interface})";
      serviceConfig = {
        ExecStart = "${pkgs.darkstat}/bin/darkstat --no-daemon --syslog -i ${interface} --wait 60 -p ${toString port} -b 127.0.0.1 --chroot /var/lib/darkstat-${name} --user darkstat --daylog daylog.csv --import darkstat.db --export darkstat.db";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
in
lib.mkMerge [
  {
    # Daily/monthly rx/tx totals, per interface: `vnstat -d`, `vnstat -i atvpn -d`, etc.
    services.vnstat.enable = true;

    users.groups.darkstat = {};
    users.users.darkstat = {
      isSystemUser = true;
      group = "darkstat";
    };

    environment.systemPackages = with pkgs; [ vnstat darkstat ];
  }

  # Captures on the physical wifi link, before WireGuard encryption wraps
  # everything for atvpn below. With the VPN up this should only ever show
  # the tunnel endpoint (91.132.139.x) plus LAN noise (DHCP/mDNS/gateway) —
  # if a real destination IP ever shows up here instead, that's a VPN leak.
  # Web UI: http://127.0.0.1:667
  (mkDarkstat {
    name = "wifi";
    interface = "wlp1s0";
    port = 667;
    unitExtra = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
    };
  })

  # Captures on the decrypted tunnel interface, i.e. your actual traffic's
  # real destinations. Tied to wg-quick-atvpn.service: starts/stops with the
  # VPN instead of racing it at boot. Web UI: http://127.0.0.1:668
  (mkDarkstat {
    name = "vpn";
    interface = "atvpn";
    port = 668;
    unitExtra = {
      after = [ "wg-quick-atvpn.service" ];
      bindsTo = [ "wg-quick-atvpn.service" ];
      wantedBy = [ "wg-quick-atvpn.service" ];
    };
  })
]
