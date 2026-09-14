{ pkgs, ... }:
let
  touchpad-filter = pkgs.writers.writePython3Bin "touchpad-filter"
    { libraries = with pkgs.python3Packages; [ evdev ]; flakeIgnore = [ "E265" "E501" ]; }
    (builtins.readFile ../../scripts/touchpad-filter);

  reset-touchpad = pkgs.writeShellScriptBin "reset-touchpad"
    (builtins.readFile ../../scripts/reset-touchpad);
in
{
  environment.systemPackages = [ touchpad-filter reset-touchpad ];

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
}
