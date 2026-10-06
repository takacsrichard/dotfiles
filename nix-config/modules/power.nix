{ pkgs, ... }:
let
  thermal-guard = pkgs.writeShellApplication {
    name = "thermal-guard";
    runtimeInputs = with pkgs; [ lm_sensors jq gawk ];
    text = builtins.readFile ../../scripts/thermal-guard.sh;
  };
in
{
  services.power-profiles-daemon.enable = false;
  zramSwap.enable = true;

  services.tlp = {
    enable = true;
    settings.DISK_LAPTOPMODE_ENABLE = 0;
  };

  services.asusd.enable = true;
  # asus-shutdown (asusctl's deferred GPU firmware writer) is useless without a
  # discrete GPU and ignores SIGTERM with SendSIGKILL=no, stalling every stop
  # for its full 45s timeout — mask it. asusd itself keeps running and still
  # applies the 90% charge limit.
  systemd.services.asus-shutdown.enable = false;

  # Force-kill all services after 10s on shutdown instead of waiting 1.5m.
  # Both system and user managers need this — user session hangs are controlled
  # by the user manager's own copy of DefaultTimeoutStopSec.
  # ShutdownWatchdogSec is a hardware watchdog fallback: if the kernel itself
  # hangs during shutdown, the watchdog resets the machine after 2 minutes.
  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "10s";
    ShutdownWatchdogSec = "2min";
  };
  systemd.user.extraConfig = "DefaultTimeoutStopSec=10s";

  systemd.services.thermal-guard = {
    description = "Thermal-based CPU frequency guard";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${thermal-guard}/bin/thermal-guard";
    };
  };

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root -"
  ];
 
  environment.systemPackages = with pkgs; [ brightnessctl lm_sensors ];
}
