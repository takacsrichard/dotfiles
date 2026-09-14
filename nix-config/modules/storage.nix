{ pkgs, ... }:
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
