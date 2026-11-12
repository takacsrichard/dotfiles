{ pkgs, ... }:
{
  systemd.services.auto-backup = {
    description = "sync to pdrive";
    path = [
      pkgs.rclone
      pkgs.bash
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "richard";
      # journald drops info-level stdout (MaxLevelStore=4 in storage.nix), so
      # log at warning instead or the script's own success/failure summary
      # line gets silently dropped
      SyslogLevel = "warning";
      ExecStart = "/home/richard/dotfiles/scripts/backup.sh";
    };
  };

  systemd.timers.auto-backup = {
    description = "Run every day at 19:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 19:00:00";
      Persistent = false; # no catch up
    };
  };

  # one-shot restic backups to ssd/hdd, triggered once per mount activation
  # (not polled, not on plug-in, not on a watched directory condition - that
  # re-fires every few minutes for as long as the disk stays mounted). a
  # drop-in on the fstab-generated mount unit itself fires the backup
  # exactly when `mount /mnt/ssd` completes, since mount activation is a
  # one-time state transition, not a persistent condition
  systemd.services.backup-ssd = {
    description = "restic backup to ssd";
    path = [
      pkgs.restic
      pkgs.bash
      pkgs.util-linux
      pkgs.coreutils
    ];
    after = [ "mnt-ssd.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "richard";
      SyslogLevel = "warning";
      ExecStart = "/home/richard/dotfiles/scripts/backup-disk.sh /mnt/ssd";
    };
  };
  systemd.units."mnt-ssd.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      Wants=backup-ssd.service
    '';
  };

  systemd.services.backup-hdd = {
    description = "restic backup to hdd";
    path = [
      pkgs.restic
      pkgs.bash
      pkgs.util-linux
      pkgs.coreutils
    ];
    after = [ "mnt-hdd.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "richard";
      SyslogLevel = "warning";
      ExecStart = "/home/richard/dotfiles/scripts/backup-disk.sh /mnt/hdd";
    };
  };
  systemd.units."mnt-hdd.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      Wants=backup-hdd.service
    '';
  };

  age.secrets.restic-password = {
    file = ../../secrets/restic-password.age;
    owner = "richard";
    mode = "0400";
  };
  age.secrets.rclone-password = {
    file = ../../secrets/rclone-password.age;
    owner = "richard";
    mode = "0400";
  };
}
