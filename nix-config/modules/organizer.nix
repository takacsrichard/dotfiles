{ pkgs, lib, ... }:
{
  # every 5 min: sort ~/Downloads by extension into subfolders, dump
  # ~/Desktop and ~/Documents files into Downloads/desktop and
  # Downloads/documents. folders are left alone. script lives at an
  # absolute path so it's editable without a rebuild.
  systemd.user.services.organize-downloads = {
    Unit.Description = "sort Downloads/Desktop/Documents files into Downloads subfolders";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${lib.makeBinPath [ pkgs.coreutils ]}";
      ExecStart = "${pkgs.python3}/bin/python3 /home/richard/dotfiles/scripts/organize-downloads.py";
      SyslogLevel = "warning";
      SyslogIdentifier = "organize-downloads";
    };
  };

  systemd.user.timers.organize-downloads = {
    Unit.Description = "run organize-downloads every 5 minutes";
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
