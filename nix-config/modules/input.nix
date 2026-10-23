{ pkgs, ... }:
let
  touchpad-filter = pkgs.writers.writePython3Bin "touchpad-filter"
    { libraries = with pkgs.python3Packages; [ evdev ]; flakeIgnore = [ "E265" "E501" ]; }
    (builtins.readFile ../../scripts/touchpad-filter);

  reset-touchpad = pkgs.writeShellScriptBin "reset-touchpad"
    (builtins.readFile ../../scripts/reset-touchpad);

  touchpad-irq = pkgs.writers.writePython3Bin "touchpad-irq"
    { flakeIgnore = [ "E265" "E501" ]; }
    (builtins.readFile "/home/richard/sys/trackers/touchpad_irq.py");

  keycounts = pkgs.stdenv.mkDerivation {
    pname = "keycounts";
    version = "unstable-2026-10-23";
    src = /home/richard/sys/trackers/keycounts;
    installPhase = ''
      install -d $out/bin $out/share/keycounts
      install keycounts $out/bin
      install keyboards/uk-header.svg $out/share/keycounts/
      install keyboards/uk-footer.svg $out/share/keycounts/
    '';
  };
in
{
  environment.systemPackages = [ touchpad-filter reset-touchpad touchpad-irq keycounts ];

  # udev: allow input group to access uinput (needed by touchpad-filter)
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';

  # sudoers: passwordless reset-touchpad
  security.sudo.extraRules = [
    {
      users = [ "richard" ];
      commands = [{
        command = "${reset-touchpad}/bin/reset-touchpad";
        options = [ "NOPASSWD" ];
      }];
    }
  ];

  # Touchpad BTN_LEFT filter (ASUS VivoBook stuck-click firmware bug)
  systemd.user.services.touchpad-filter = {
    description = "Touchpad BTN_LEFT filter";
    wantedBy = [ "default.target" ];
    after = [ "default.target" ];
    unitConfig = {
      StartLimitIntervalSec = "120s";
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${touchpad-filter}/bin/touchpad-filter";
      Restart = "on-failure";
      RestartSec = "3s";
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "touchpad-filter";
    };
  };

  # Personal tracker: logs ASUE120B touchpad IRQ counter every 5min
  systemd.user.services.touchpad-irq = {
    description = "Touchpad IRQ counter tracker";
    wantedBy = [ "default.target" ];
    after = [ "default.target" ];
    unitConfig = {
      StartLimitIntervalSec = "120s";
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${touchpad-irq}/bin/touchpad-irq";
      Restart = "on-failure";
      RestartSec = "3s";
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "touchpad-irq";
    };
  };

  # Keyboard keypress-count heatmap data. Needs raw /dev/input access, so
  # unlike the trackers above this runs as a system (root) service, not a
  # per-user one.
  systemd.tmpfiles.rules = [
    "d /var/lib/keycounts 0755 root root -"
  ];
  systemd.services.keycounts = {
    description = "Keyboard keypress count tracker";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${keycounts}/bin/keycounts record";
      Restart = "on-failure";
      RestartSec = "3s";
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "keycounts";
    };
  };
}
