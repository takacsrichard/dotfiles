{ config, pkgs, pkgs-unstable, ... }:
let
  dotfilesConfig = builtins.readDir ../.config;
  autoExcluded = [ "systemd" "mimeapps.list" "fontconfig" "doublecmd" ];
  autoConfigEntries = builtins.listToAttrs (
    builtins.map (name: {
      name = ".config/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/${name}";
    }) (builtins.filter (n: !builtins.elem n autoExcluded) (builtins.attrNames dotfilesConfig))
  );
in
{
  imports = [ ./modules/firefox.nix ];

  home.username = "richard";
  home.homeDirectory = "/home/richard";
  home.stateVersion = "24.05";
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    ripgrep
    fastfetch
    bluetui
    eza
    zoxide
    fzf
    jq
    ncdu
    yazi
    cowsay
    cmatrix
    yt-dlp
    deno
    translate-shell
    tree
    wget
    rclone
    htop
    rsync
    speedtest-cli
    sysstat
    unzip
    unrar
    p7zip
    github-cli
    yq-go
    python3
    uv
    libreoffice-still
    vesktop
    pnpm
    plocate
    nixfmt
    kitty
    bc
    curl
    less
    mc
    nnn
    file-rename
    pyright
    strace
    psmisc
    testdisk
    tesseract
    trash-cli
    fdupes
    graphviz
    imagemagick
    inxi
    pkgs-unstable.antigravity-cli
    hyprlock
    hypridle
    wlogout
    fuzzel
    grim
    slurp
    wf-recorder
    waybar
    mako
    cliphist
    claude-code
    doublecmd
    restic
    git
    libnatpmp
    qview
    imv
    mpv
    anki
    qbittorrent
    tuxguitar
    wl-clipboard
    rbw
    pinentry-qt
    just
    neovim
    fd
    syncthing
    gdu
    jdupes
    rustc
    cargo
    gcc
    tree-sitter
    nodejs
    librsvg
    tmux
    thunderbird
    (pkgs.writeShellApplication {
      name = "netwatch";
      runtimeInputs = with pkgs; [ tshark iproute2 gawk util-linux ];
      text = builtins.readFile ../scripts/netwatch;
    })
  ];


  home.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    initContent = ''
      [ -f ~/dotfiles/.zshrc ] && source ~/dotfiles/.zshrc
    '';
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/jpeg"         = "qview.desktop";
      "image/png"          = "qview.desktop";
      "image/gif"          = "qview.desktop";
      "image/webp"         = "qview.desktop";
      "image/bmp"          = "qview.desktop";
      "image/tiff"         = "qview.desktop";
      "image/svg+xml"      = "qview.desktop";
      "image/x-icon"       = "qview.desktop";
      "video/mp4"          = "mpv.desktop";
      "video/x-matroska"   = "mpv.desktop";
      "video/webm"         = "mpv.desktop";
      "video/avi"          = "mpv.desktop";
      "video/quicktime"    = "mpv.desktop";
      "video/x-msvideo"    = "mpv.desktop";
      "video/mpeg"         = "mpv.desktop";
      "video/ogg"          = "mpv.desktop";
      "video/x-flv"        = "mpv.desktop";
      "video/3gpp"         = "mpv.desktop";
      "audio/x-opus+ogg"   = "mpv.desktop";
    };
    associations.removed = {
      "audio/x-opus+ogg" = "org.kde.elisa.desktop";
    };
  };
  xdg.configFile."mimeapps.list".force = true;

  # Auto-symlink everything from ~/dotfiles/.config/ except entries managed
  # by home-manager itself (systemd, mimeapps.list) or needing per-file
  # handling (fontconfig — HM owns conf.d/ alongside fonts.conf).
  # To add a new app: drop its config into ~/dotfiles/.config/ and rebuild.
  home.file = autoConfigEntries // {
    ".config/fontconfig/fonts.conf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/fontconfig/fonts.conf";

    ".config/rbw/config.json".text = builtins.toJSON {
      email             = "takacs.richard121@gmail.com";
      sso_id            = null;
      base_url          = "https://api.bitwarden.eu";
      identity_url      = "https://identity.bitwarden.eu";
      ui_url            = "https://vault.bitwarden.eu";
      notifications_url = "https://notifications.bitwarden.eu";
      lock_timeout      = 3600;
      sync_interval     = 3600;
      pinentry          = "pinentry";
      client_cert_path  = null;
    };

    ".gitconfig".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.gitconfig";

    ".gtkrc-2.0".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.gtkrc-2.0";

    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.claude/settings.json";

    # doublecmd: only track config files, not runtime files (history, tabs, sessions)
    ".config/doublecmd/doublecmd.xml".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/doublecmd/doublecmd.xml";
    ".config/doublecmd/shortcuts.scf".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/doublecmd/shortcuts.scf";
    ".config/doublecmd/colors.json".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/doublecmd/colors.json";
    ".config/doublecmd/highlighters.xml".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/doublecmd/highlighters.xml";
    ".config/doublecmd/multiarc.ini".source =
      config.lib.file.mkOutOfStoreSymlink "/home/richard/dotfiles/.config/doublecmd/multiarc.ini";
  };

}
