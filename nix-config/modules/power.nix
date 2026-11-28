{ pkgs, ... }:
let
  thermal-guard = pkgs.writeShellApplication {
    name = "thermal-guard";
    runtimeInputs = with pkgs; [
      lm_sensors
      jq
      gawk
    ];
    text = builtins.readFile ../../scripts/thermal-guard.sh;
  };

  # asusd is supposed to switch the platform profile to quiet on battery and
  # performance on ac (see /etc/asusd/asusd.ron), but it writes its own ron
  # file after every change, that write triggers an inotify self-read, and
  # during an ac plug/unplug specifically that self-read races the real
  # transition and can overshoot past the intended profile (quiet -> balanced
  # has been observed). measured cost: ~0.7w continuously discharging on
  # battery while stuck in balanced instead of quiet. see
  # ~/sys/battanal/opencode_continuation/FINDINGS_20261127.md.
  #
  # fix: let asusd do its (possibly wrong) thing, then re-assert the right
  # profile a couple seconds later, once its internal race has settled.
  asusd-profile-fixup = pkgs.writeShellApplication {
    name = "asusd-profile-fixup";
    runtimeInputs = [ pkgs.asusctl ];
    text = ''
      sleep 2
      online=$(cat /sys/class/power_supply/AC0/online)
      if [ "$online" = "1" ]; then
        asusctl profile set Performance
      else
        asusctl profile set Quiet
      fi
    '';
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

  systemd.services.asusd-profile-fixup = {
    description = "re-apply the intended asusd platform profile after an ac transition";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${asusd-profile-fixup}/bin/asusd-profile-fixup";
    };
  };

  # power_supply/AC0 online flips on every plug/unplug; kick the fixup
  # service instead of doing the sleep/correction inline in udev (RUN+
  # blocks the udev worker, and shouldn't sleep).
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="AC0", ATTR{online}=="0", RUN+="${pkgs.systemd}/bin/systemctl --no-block start asusd-profile-fixup.service"
    SUBSYSTEM=="power_supply", KERNEL=="AC0", ATTR{online}=="1", RUN+="${pkgs.systemd}/bin/systemctl --no-block start asusd-profile-fixup.service"
  '';

  environment.systemPackages = with pkgs; [
    brightnessctl
    lm_sensors
  ];
}
