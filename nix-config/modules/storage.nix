{ pkgs, config, ... }:
{
  fileSystems."/mnt/hdd" = {
    device = "/dev/disk/by-uuid/00FD-8196";
    fsType = "exfat";
    options = [ "uid=1000" "gid=100" "nofail" "noauto" ];
  };

  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-uuid/6AE7-F045";
    fsType = "exfat";
    options = [ "uid=1000" "gid=100" "nofail" "noauto" ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/hdd 0755 richard users -"
    "d /mnt/ssd 0755 richard users -"
  ];

  environment.systemPackages = with pkgs; [
    exfatprogs
    e2fsprogs
    btrfs-progs
  ];

  # Btrfs: monthly scrub for data integrity (only need to list / since all
  # subvolumes are on the same device)
  services.btrfs.autoScrub = {
    enable = true;
    interval = "*-*-1 16:00:00";
    fileSystems = [ "/" ];
  };

  # Btrfs: monthly balance to reclaim space from partially-empty block
  # groups (dusage=50 only rewrites chunks that are <50% full, so this is
  # cheap). No upstream NixOS module for this yet, so declared by hand
  # following the same pattern as services.btrfs.autoScrub.
  systemd.timers."btrfs-balance-root" = {
    description = "regular btrfs balance timer on /";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-2 16:00:00";
      AccuracySec = "1d";
      Persistent = true;
    };
  };
  systemd.services."btrfs-balance-root" = {
    description = "btrfs balance on /";
    documentation = [ "man:btrfs-balance(8)" ];
    conflicts = [ "shutdown.target" "sleep.target" ];
    before = [ "shutdown.target" "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs balance start -dusage=50 /";
    };
  };

  # Trim: builtin NixOS module, weekly by default; explicit here for clarity
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # putzfrau: weekly cleanup of caches, nix generations, etc. (see
  # ~/sys/sys/putzfrau.sh). Persistent=true catches up a missed run if the
  # laptop was off at the scheduled time.
  systemd.timers."putzfrau" = {
    description = "weekly putzfrau cleanup timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sat *-*-* 11:00:00";
      AccuracySec = "1h";
      Persistent = true;
    };
  };
  # passwordless sudo for the one root-only step in putzfrau.sh (journal vacuum)
  security.sudo.extraRules = [
    {
      users = [ "richard" ];
      commands = [{
        command = "${config.systemd.package}/bin/journalctl --vacuum-time=2weeks";
        options = [ "NOPASSWD" ];
      }];
    }
  ];

  systemd.services."putzfrau" = {
    description = "putzfrau cleanup";
    path = [ "/run/wrappers" ] ++ (with pkgs; [ bash restic docker python3 go nodejs uv procps ]);
    serviceConfig = {
      Type = "oneshot";
      User = "richard";
      Nice = 19;
      IOSchedulingClass = "idle";
      Environment = "HOME=/home/richard";
      # journald drops info-level stdout (MaxLevelStore=4 below), so log this
      # unit's output at warning instead or failures show up with no reason
      SyslogLevel = "warning";
      ExecStart = "/home/richard/sys/jobs/putzfrau.sh";
    };
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };


  services.journald.extraConfig = ''
    SystemMaxUse=200M
    SystemKeepFree=0
    MaxRetentionSec=2weeks
    MaxLevelStore=4
  '';


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
}
