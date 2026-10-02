{ pkgs, ... }:
{
  systemd.services.auto-backup = {
    description = "restic backup to ssd + gdrive + pdrive";
    path = [ pkgs.restic pkgs.rclone pkgs.bash ];
    serviceConfig = {
      Type = "oneshot";
      User = "richard";
      ExecStart = "/home/richard/dotfiles/scripts/backup.sh";
    };
    # TODO this means it only runs if ssd is mounted at that point. script itself exits early if ssd not mounted. known. no retry
    unitConfig.ConditionPathIsMountPoint = "/mnt/ssd";
  };

  systemd.timers.auto-backup = {
    description = "Run every other day at 19pm";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # start by first months day the count so possible that 31st and 1st are both ran ?
      OnCalendar = "*-*-01/2 19:00:00";
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
