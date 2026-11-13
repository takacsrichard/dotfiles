{ pkgs, lib, ... }:
let
  # ~/sys/trackers lives outside dotfiles (not under git) and also holds the
  # trackers' own growing csv output, so it's read directly rather than
  # vendored or pulled in as a flake input. pathExists guards every use below
  # so a missing dir (fresh install, not yet restored from backup) only drops
  # these 4 personal trackers instead of failing the whole rebuild.
  trackersDir = "/home/richard/sys/trackers";
  hasTrackers = builtins.pathExists trackersDir;

  touchpad-filter = pkgs.writers.writePython3Bin "touchpad-filter" {
    libraries = with pkgs.python3Packages; [ evdev ];
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } (builtins.readFile ../../scripts/touchpad-filter);

  reset-touchpad = pkgs.writeShellScriptBin "reset-touchpad" (
    builtins.readFile ../../scripts/reset-touchpad
  );

  touchpad-irq = pkgs.writers.writePython3Bin "touchpad-irq" {
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } (builtins.readFile "${trackersDir}/touchpad_irq.py");

  bluetooth-tracker = pkgs.writers.writePython3Bin "bluetooth-tracker" {
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } (builtins.readFile "${trackersDir}/bluetooth_tracker.py");

  workspaces-tracker = pkgs.writers.writePython3Bin "workspaces-tracker" {
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } (builtins.readFile "${trackersDir}/workspaces_tracker.py");

  keylog = pkgs.writers.writePython3Bin "keylog" {
    libraries = with pkgs.python3Packages; [ evdev ];
    flakeIgnore = [
      "E265"
      "E501"
    ];
  } (builtins.readFile "${trackersDir}/keylog/keylog.py");

in
{
  environment.systemPackages = [
    touchpad-filter
    reset-touchpad
  ]
  ++ lib.optionals hasTrackers [
    touchpad-irq
    bluetooth-tracker
    workspaces-tracker
    keylog
  ];

  # udev: allow input group to access uinput (needed by touchpad-filter)
  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660"
  '';

  # sudoers: passwordless reset-touchpad
  security.sudo.extraRules = [
    {
      users = [ "richard" ];
      commands = [
        {
          command = "${reset-touchpad}/bin/reset-touchpad";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Touchpad BTN_LEFT filter (ASUS VivoBook stuck-click firmware bug)
  # disabled: not needed right now, commented out so it doesn't even try to start
  # systemd.user.services.touchpad-filter = {
  #   description = "Touchpad BTN_LEFT filter";
  #   wantedBy = [ "default.target" ];
  #   after = [ "default.target" ];
  #   unitConfig = {
  #     StartLimitIntervalSec = "120s";
  #     StartLimitBurst = 5;
  #   };
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${touchpad-filter}/bin/touchpad-filter";
  #     Restart = "on-failure";
  #     RestartSec = "3s";
  #     StandardOutput = "journal";
  #     StandardError = "journal";
  #     SyslogIdentifier = "touchpad-filter";
  #   };
  # };

  # Personal trackers: only wired up if ~/sys/trackers is actually present
  # (see hasTrackers above)
  systemd.user.services = lib.optionalAttrs hasTrackers {
    # logs ASUE120B touchpad IRQ counter every 5min
    touchpad-irq = {
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

    # logs connected bluetooth devices every 2min
    bluetooth-tracker = {
      description = "Bluetooth connection tracker";
      wantedBy = [ "default.target" ];
      after = [ "default.target" ];
      path = [ pkgs.bluez ];
      unitConfig = {
        StartLimitIntervalSec = "120s";
        StartLimitBurst = 5;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${bluetooth-tracker}/bin/bluetooth-tracker";
        Restart = "on-failure";
        RestartSec = "3s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "bluetooth-tracker";
      };
    };

    # logs count of active hyprland workspaces every 2min
    workspaces-tracker = {
      description = "Hyprland active workspace count tracker";
      wantedBy = [ "default.target" ];
      after = [ "default.target" ];
      path = [ pkgs.hyprland ];
      unitConfig = {
        StartLimitIntervalSec = "120s";
        StartLimitBurst = 5;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${workspaces-tracker}/bin/workspaces-tracker";
        Restart = "on-failure";
        RestartSec = "3s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "workspaces-tracker";
      };
    };

    # logs every keystroke (timestamp, key, up/down/repeat)
    keylog = {
      description = "Keystroke logger";
      wantedBy = [ "default.target" ];
      after = [ "default.target" ];
      unitConfig = {
        StartLimitIntervalSec = "120s";
        StartLimitBurst = 5;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${keylog}/bin/keylog";
        Restart = "on-failure";
        RestartSec = "3s";
        StandardOutput = "journal";
        StandardError = "journal";
        SyslogIdentifier = "keylog";
      };
    };
  };
}
