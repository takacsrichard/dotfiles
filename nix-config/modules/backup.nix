{ pkgs, ... }:
{
  systemd.services.auto-backup = {
    description = "restic backup to ssd/hdd + pdrive";
    path = [ pkgs.restic pkgs.rclone pkgs.bash pkgs.util-linux ];
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
