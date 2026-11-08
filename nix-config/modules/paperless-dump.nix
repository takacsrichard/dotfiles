{ pkgs, lib, ... }:
{
  # daily: pull anything new from gdrive:paperless (general document dump) and
  # feed it straight into paperless's consume dir -- categorization happens via
  # the filename-matching workflows pushed by scripts/paperless/sync.py.
  # user-level unit, no sudo needed -- just `home-manager switch`. script lives
  # at an absolute path so it's editable without a rebuild.
  systemd.user.services.paperless-dump-sync = {
    Unit.Description = "sync gdrive:paperless into paperless";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${lib.makeBinPath [ pkgs.rclone pkgs.coreutils ]}";
      ExecStart = "${pkgs.python3}/bin/python3 /home/richard/dotfiles/scripts/paperless-dump-sync.py";
      # journald MaxLevelStore=4 drops info-level stdout, so a quiet success
      # run would otherwise vanish entirely -- log at warning instead
      SyslogLevel = "warning";
      SyslogIdentifier = "paperless-dump-sync";
    };
  };

  systemd.user.timers.paperless-dump-sync = {
    Unit.Description = "run paperless-dump-sync daily";
    Timer = {
      OnCalendar = "*-*-* 05:05:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
