{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    smartmontools
    btrfs-heatmap
  ];

  systemd.tmpfiles.rules = [
    "d /home/richard/dashboard/data 0755 richard users -"
  ];

  # services.tailscale.enable = true; # not worth it, dashboard stays laptop-only

  # smartctl: short self-test on the nvme drive every 5 days, result dumped
  # as json for the dashboard sys tab
  systemd.services."smartctl-test" = {
    description = "short smartctl self-test on nvme0n1";
    path = with pkgs; [
      smartmontools
      bash
      coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      # journald drops info-level stdout (MaxLevelStore=4 in storage.nix), so
      # log at warning instead or failures show no reason
      SyslogLevel = "warning";
      ExecStart = "/home/richard/dotfiles/scripts/smartctl-test.sh";
    };
  };
  systemd.timers."smartctl-test" = {
    description = "run smartctl-test every 5 days";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-1/5 03:00:00";
      Persistent = true;
    };
  };

  # btrfs-heatmap: chunk heatmap png of / every 2 days, for the dashboard sys tab
  systemd.services."btrfs-heatmap" = {
    description = "generate btrfs heatmap png for /";
    path = with pkgs; [
      btrfs-heatmap
      bash
      coreutils
    ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      IOSchedulingClass = "idle";
      SyslogLevel = "warning";
      ExecStart = "/home/richard/dotfiles/scripts/btrfs-heatmap.sh";
    };
  };
  systemd.timers."btrfs-heatmap" = {
    description = "run btrfs-heatmap every 2 days";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-1/2 03:30:00";
      Persistent = true;
    };
  };

  # disk-usage: nvme root + /mnt/{ssd,hdd,iphone} (if mounted) + rclone
  # gdrive/pdrive quotas, once a day, for the dashboard sys tab. reuses the
  # same rclone config password secret as auto-backup.
  systemd.services."disk-usage" = {
    description = "collect local + rclone disk usage for dashboard";
    path = with pkgs; [
      python3
      rclone
    ];
    serviceConfig = {
      Type = "oneshot";
      Nice = 19;
      SyslogLevel = "warning";
      # no User= (root, for /mnt + nvme access) means $HOME defaults to /root,
      # so rclone can't find richard's ~/.config/rclone/rclone.conf unless we
      # point HOME at it explicitly - same trap as the putzfrau service above
      Environment = "HOME=/home/richard";
      ExecStart = "/home/richard/dotfiles/scripts/disk-usage.py";
    };
  };
  systemd.timers."disk-usage" = {
    description = "run disk-usage daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
    };
  };
}
