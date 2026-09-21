{ pkgs, ... }:
{
  # Daily/monthly rx/tx totals per interface: `vnstat -d` / `vnstat -m`
  services.vnstat.enable = true;

  # Per-host breakdown of who traffic went to, with a small web UI at
  # http://127.0.0.1:667 (loopback-only, no NixOS module exists for this
  # package so the unit is hand-rolled).
  users.groups.darkstat = {};
  users.users.darkstat = {
    isSystemUser = true;
    group = "darkstat";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/darkstat 0750 darkstat darkstat -"
  ];

  systemd.services.darkstat = {
    description = "darkstat per-host network traffic analyzer";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      # darkstat starts as root to open the raw capture socket, then drops
      # to --user/--chroot itself; --wait rides out NetworkManager bringing
      # wlp1s0 up after boot. --import/--export persist the in-memory table
      # across restarts, --daylog keeps a running daily rx/tx/pkt log.
      ExecStart = "${pkgs.darkstat}/bin/darkstat --no-daemon --syslog -i wlp1s0 --wait 60 -p 667 -b 127.0.0.1 --chroot /var/lib/darkstat --user darkstat --daylog daylog.csv --import darkstat.db --export darkstat.db";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  environment.systemPackages = with pkgs; [ vnstat darkstat ];
}
