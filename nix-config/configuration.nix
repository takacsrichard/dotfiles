{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/vpn.nix
    ./modules/boot.nix
    ./modules/networking.nix
    ./modules/desktop.nix
    ./modules/audio.nix
    ./modules/bluetooth.nix
    ./modules/power.nix
    ./modules/input.nix
    ./modules/packages.nix
    ./modules/storage.nix
  ];

  # Run home-manager activation after graphical.target instead of before it,
  # so the login screen appears ~3.5s earlier. home-manager finishes in ~3.5s
  # which is less than typical password-typing time, so dotfiles are ready
  # before the user session starts in normal use. On very fast logins (<3s)
  # symlinks may not be fully applied yet — roll back if this is a problem.
  # lib.mkForce risk: if another module also sets these with mkForce, last one wins silently
  systemd.services."home-manager-richard" = {
    after    = lib.mkForce [ "graphical.target" "nix-daemon.socket" ];
    before   = lib.mkForce [];
    wantedBy = lib.mkForce [ "graphical.target" ];
  };

  time.timeZone = "Europe/Vienna";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT    = "de_AT.UTF-8";
    LC_MONETARY       = "de_AT.UTF-8";
    LC_NAME           = "de_AT.UTF-8";
    LC_NUMERIC        = "de_AT.UTF-8";
    LC_PAPER          = "de_AT.UTF-8";
    LC_TELEPHONE      = "de_AT.UTF-8";
    LC_TIME           = "de_AT.UTF-8";
  };
  console.keyMap = "hu";

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "electron-41.9.1"  # vesktop on 26.05; remove once vesktop updates past electron-41
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.http-connections = 1;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  
  virtualisation.docker.enable = true;

  programs.zsh.enable = true;
  programs.wireshark.enable = true;

  # FHS compatibility for pip/uv venvs with compiled C extensions (numpy, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  users.users."richard" = {
    isNormalUser = true;
    description = "richard";
    extraGroups = [ "networkmanager" "wheel" "input" "video" "plocate" "wireshark" "docker" ];
    shell = pkgs.zsh;
    packages = with pkgs; [ kdePackages.kate ];
  };

  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
  };

  services.cron = {
    enable = true;
    systemCronJobs = [
      # Keep ProtonDrive API session alive — token expires after inactivity
      "0 */12 * * * richard ${pkgs.rclone}/bin/rclone lsjson pdrive: --max-depth 1 > /dev/null 2>&1"
    ];
  };

  services.journald.extraConfig = ''
    SystemMaxUse=100T
    SystemKeepFree=0
  '';

  system.stateVersion = "26.05";
}
