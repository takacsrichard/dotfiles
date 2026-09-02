{ config, pkgs, lib, agenix, ... }:

let
  touchpad-filter = pkgs.writers.writePython3Bin "touchpad-filter"
    { libraries = with pkgs.python3Packages; [ evdev ]; flakeIgnore = [ "E265" "E501" ]; }
    (builtins.readFile ../scripts/touchpad-filter);

  reset-touchpad = pkgs.writeShellScriptBin "reset-touchpad"
    (builtins.readFile ../scripts/reset-touchpad);

  sddm-sugar-candy = pkgs.stdenv.mkDerivation {
    name = "sddm-sugar-candy";
    src = ../system/sddm-themes;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/sugar-candy
      cp -r . $out/share/sddm/themes/sugar-candy/
    '';
  };

  thermal-guard = pkgs.writeShellApplication {
    name = "thermal-guard";
    runtimeInputs = with pkgs; [ lm_sensors jq gawk ];
    text = builtins.readFile ../scripts/thermal-guard.sh;
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules/vpn.nix
  ];

  # Protonmail
  services.protonmail-bridge.enable = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  # Default (older, stable) kernel instead of linuxPackages_latest while
  # chasing the intermittent poweroff hang — rules bleeding-edge regressions
  # in or out. consoleLogLevel=7 keeps kernel INFO messages ("reboot: Power
  # down") visible on screen during shutdown so a hang can be localized to
  # kernel vs. firmware.
  boot.kernelPackages = pkgs.linuxPackages;
  boot.consoleLogLevel = 1;
  boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1;
  boot.kernelParams = [ "reboot=efi" "amd_iommu=off" ];
  boot.kernel.sysctl."vm.vfs_cache_pressure" = 50;
  # Network
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openconnect ];
  };
  networking.networkmanager.dns = "systemd-resolved";

  services.resolved.enable = true;
  # Run home-manager activation after graphical.target instead of before it,
  # so the login screen appears ~3.5s earlier. home-manager finishes in ~3.5s
  # which is less than typical password-typing time, so dotfiles are ready
  # before the user session starts in normal use. On very fast logins (<3s)
  # symlinks may not be fully applied yet — roll back if this is a problem.
  systemd.services."home-manager-richard" = {
    after    = lib.mkForce [ "graphical.target" "nix-daemon.socket" ];
    before   = lib.mkForce [];
    wantedBy = lib.mkForce [ "graphical.target" ];
  };
 
  # services.openssh.enable=true;
  # Locale / timezone
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

  # Desktop
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "hu"; variant = ""; };
  # SDDM (sugar-candy) — kept for easy rollback, swap comments to re-enable
  # services.displayManager.sddm = {
  #   enable = true;
  #   theme = "sugar-candy";
  #   extraPackages = [ pkgs.kdePackages.qt5compat ];
  #   package = lib.mkForce (pkgs.kdePackages.sddm.override {
  #     sddm-unwrapped = pkgs.kdePackages.sddm.unwrapped.overrideAttrs (old: {
  #       postInstall = (old.postInstall or "") + ''
  #         ln -sf $out/bin/sddm-greeter-qt6 $out/bin/sddm-greeter
  #       '';
  #     });
  #   });
  #   settings = {
  #     Theme = {
  #       CursorTheme = "GoogleDot-White";
  #       Font = "Noto Sans,10,-1,0,400,0,0,0,0,0,0,0,0,0,0,1";
  #     };
  #     Users = {
  #       MaximumUid = 60513;
  #       MinimumUid = 1000;
  #     };
  #   };
  # };

  # greetd + tuigreet (lightweight TUI greeter, replaces SDDM)
  # F2 = session list, F3 = session picker, remembers last user+session per user
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --asterisks \
            --remember \
            --remember-user-session \
            --sessions ${config.services.displayManager.sessionData.desktops}/share/xsessions:${config.services.displayManager.sessionData.desktops}/share/wayland-sessions
        '';
        user = "greeter";
      };
    };
  };
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = true;
  programs.hyprland.enable = true;

  # Audio
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Printing
  # services.printing.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.bluetooth.settings.General.Experimental = true;
  services.blueman.enable = true;

  # Power management
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

  systemd.tmpfiles.rules = [
    "d /etc/asusd 0755 root root -"
    "d /var/cache/tuigreet 0755 greeter greeter -"
  ];

  # Fonts
  fonts.packages = with pkgs; [
    material-symbols
    nerd-fonts.jetbrains-mono
  ];

  # Nix settings
  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.http-connections = 1;


  # Shell
  programs.firefox.enable = true;
  programs.zsh.enable = true;
  programs.wireshark.enable = true;

  # FHS compatibility for pip/uv venvs with compiled C extensions (numpy, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    openssl
  ];

  # Users
  users.users."richard" = {
    isNormalUser = true;
    description = "richard";
    extraGroups = [ "networkmanager" "wheel" "input" "video" "plocate" "wireshark" ];
    shell = pkgs.zsh;
    packages = with pkgs; [ kdePackages.kate ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    agenix.packages.x86_64-linux.default
    wireguard-tools
    ffmpeg
    brightnessctl
    touchpad-filter
    reset-touchpad
    sddm-sugar-candy
    lm_sensors
    # R / data science
    (rWrapper.override {
      packages = with rPackages; [
        # document rendering
        rmarkdown knitr
        # core data wrangling & viz
        tidyverse ggplot2 dplyr tidyr readr lubridate stringr purrr
        data_table
        # stats & ML
        caret forecast zoo xts
        # quant finance
        quantmod TTR PerformanceAnalytics tidyquant tseries rugarch
        # misc utils
        plotly DT scales
      ];
    })
    rstudio
    (texlive.combine {
      inherit (texlive)
        scheme-medium
        framed
        titling
        enumitem
        parskip;
    })
    pandoc
  ];

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

  # Thermal guard: caps CPU freq when temperature exceeds threshold
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

  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily";
  };

  # Cron
  services.cron = {
    enable = true;
    systemCronJobs = [
      # Keep ProtonDrive API session alive — token expires after inactivity
      "0 */12 * * * richard ${pkgs.rclone}/bin/rclone lsjson pdrive: --max-depth 1 > /dev/null 2>&1"
    ];
  };

  # Btrfs: monthly scrub for data integrity (only need to list / since all
  # subvolumes are on the same device)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Btrfs: hourly snapshots of /home via snapper
  # persistentTimer ensures one snapshot runs on next boot if laptop was off
  services.snapper.persistentTimer = true;
  services.snapper.configs.home = {
    SUBVOLUME = "/home";
    ALLOW_USERS = [ "richard" ];
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_MIN_AGE = 1800;
    TIMELINE_LIMIT_HOURLY = "6";
    TIMELINE_LIMIT_DAILY = "3";
    TIMELINE_LIMIT_WEEKLY = "2";
    TIMELINE_LIMIT_MONTHLY = "1";
  };


  system.stateVersion = "26.05";
}
