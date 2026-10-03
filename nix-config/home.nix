{ config, pkgs, pkgs-unstable, ... }:
let
  dotfilesConfig = builtins.readDir ../.config;
  autoExcluded = [ "systemd" "mimeapps.list" "fontconfig" "doublecmd" ];
  autoConfigEntries = builtins.listToAttrs (
    builtins.map (name: {
      name = ".config/${name}";
      value.source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/${name}";
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
    yazi
    delta
    bat
    sd
    rm-improved
    cowsay
    direnv
    libqalculate
    cmatrix
    yt-dlp
    deno
    translate-shell
    tree
    pastel
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
    pnpm
    nixfmt
    kitty
    bc
    btdu
    curl
    less
    dust
    choose
    file-rename
    pyright
    strace
    psmisc
    testdisk
    tesseract
    trash-cli
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
    swayimg
    mpv
    anki
    qbittorrent
    tuxguitar
    wl-clipboard
    rbw
    pinentry-qt
    just
    zathura
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
    hyperfine
    tldr
    procs
    duf
    btop
    lazygit
  ];


  home.sessionVariables.NIXOS_OZONE_WL = "1";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = false;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "";
      plugins = [ "git" ];
    };
    initContent = ''
      [ -f ~/dotfiles/.zshrc ] && source ~/dotfiles/.zshrc
    '';
  };


  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      "$schema" = ''https://starship.rs/config-schema.json'';
      format = ''
$directory$git_branch$git_status$python $time
$character'';
      aws = {
        format = ''\[[$symbol($profile)(\($region\))(\[$duration\])]($style)\]'';
      };
      azure = {
        format = ''\[[$symbol($subscription)]($style)\]'';
      };
      battery = {
        format = ''\[[$symbol$percentage]($style)\]'';
      };
      buf = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      bun = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      c = {
        format = ''\[[$symbol($version(-$name))]($style)\]'';
      };
      cmake = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      cmd_duration = {
        format = ''\[[⏱ $duration]($style)\]'';
        disabled = true;
      };
      cobol = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      conda = {
        format = ''\[[$symbol$environment]($style)\]'';
      };
      container = {
        format = ''\[[$symbol \[$name\]]($style)\]'';
      };
      cpp = {
        format = ''\[[$symbol($version(-$name))]($style)\]'';
      };
      crystal = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      daml = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      dart = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      deno = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      direnv = {
        format = ''\[[$symbol$loaded/$allowed]($style)\]'';
      };
      docker_context = {
        format = ''\[[$symbol$context]($style)\]'';
      };
      dotnet = {
        format = ''\[[$symbol($version)(🎯 $tfm)]($style)\]'';
      };
      elixir = {
        format = ''\[[$symbol($version \(OTP $otp_version\))]($style)\]'';
      };
      elm = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      erlang = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      fennel = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      fortran = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      fossil_branch = {
        format = ''\[[$symbol$branch]($style)\]'';
      };
      fossil_metrics = {
        format = ''\[[+$added]($added_style)\]\[[-$deleted]($deleted_style)\]'';
      };
      gcloud = {
        format = ''\[[$symbol$account(@$domain)(\($region\))]($style)\]'';
      };
      git_branch = {
        format = ''\[[$symbol$branch]($style)\]'';
      };
      git_commit = {
        format = ''\[[\($hash$tag\)]($style)\]'';
      };
      git_metrics = {
        format = ''\[[+$added]($added_style)\]\[[-$deleted]($deleted_style)\]'';
      };
      git_state = {
        format = ''\[[$state ($progress_current/$progress_total)]($style)\]'';
      };
      git_status = {
        format = ''([\[$all_status$ahead_behind\]]($style))'';
      };
      gleam = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      golang = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      gradle = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      guix_shell = {
        format = ''\[[$symbol]($style)\]'';
      };
      haskell = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      haxe = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      helm = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      hg_branch = {
        format = ''\[[$symbol$branch]($style)\]'';
      };
      hostname = {
        format = ''\[[$ssh_symbol($hostname)]($style)\] '';
      };
      java = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      jobs = {
        format = ''\[[$symbol$number]($style)\]'';
      };
      julia = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      kotlin = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      kubernetes = {
        format = ''\[[$symbol$context( \($namespace\))]($style)\]'';
      };
      localip = {
        format = ''\[[$localipv4]($style)\]'';
      };
      lua = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      maven = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      memory_usage = {
        format = ''\[$symbol[$ram( | $swap)]($style)\]'';
      };
      meson = {
        format = ''\[[$symbol$project]($style)\]'';
      };
      mise = {
        format = ''\[[$symbol$health]($style)\]'';
      };
      mojo = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      nats = {
        format = ''\[[$symbol$name]($style)\]'';
      };
      netns = {
        format = ''\[[$symbol \[$name\]]($style)\]'';
      };
      nim = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      nix_shell = {
        format = ''\[[$symbol$state( \($name\))]($style)\]'';
      };
      nodejs = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      ocaml = {
        format = ''\[[$symbol($version)(\($switch_indicator$switch_name\))]($style)\]'';
      };
      odin = {
        format = ''\[[$symbol($version )]($style)\]'';
      };
      opa = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      openstack = {
        format = ''\[[$symbol$cloud(\($project\))]($style)\]'';
      };
      os = {
        format = ''\[[$symbol]($style)\]'';
      };
      package = {
        format = ''\[[$symbol$version]($style)\]'';
      };
      perl = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      php = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      pijul_channel = {
        format = ''\[[$symbol$channel]($style)\]'';
      };
      pixi = {
        format = ''\[[$symbol$version( $environment)]($style)\]'';
      };
      pulumi = {
        format = ''\[[$symbol$stack]($style)\]'';
      };
      purescript = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      python = {
        format = ''\[[($virtualenv)]($style)\]'';
        detect_extensions = [ ];
        detect_files = [ ];
        detect_folders = [ ];
      };
      quarto = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      raku = {
        format = ''\[[$symbol($version-$vm_version)]($style)\]'';
      };
      red = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      rlang = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      ruby = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      rust = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      scala = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      shell = {
        format = ''\[[$indicator]($style)\]'';
      };
      singularity = {
        format = ''\[[$symbol\[$env\]]($style)\]'';
      };
      solidity = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      spack = {
        format = ''\[[$symbol$environment]($style)\]'';
      };
      status = {
        format = ''\[[$symbol$status]($style)\]'';
      };
      sudo = {
        format = ''\[[as $symbol]($style)\]'';
      };
      swift = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      terraform = {
        format = ''\[[$symbol$workspace]($style)\]'';
      };
      time = {
        format = ''\[[$time]($style)\]'';
        time_format = ''%H:%M'';
        disabled = false;
      };
      typst = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      username = {
        format = ''\[[$user]($style)\]'';
      };
      vagrant = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      vcsh = {
        format = ''\[vcsh [$symbol$repo]($style)\]'';
      };
      vlang = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      xmake = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
      zig = {
        format = ''\[[$symbol($version)]($style)\]'';
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/jpeg"         = "swayimg.desktop";
      "image/png"          = "swayimg.desktop";
      "image/gif"          = "swayimg.desktop";
      "image/webp"         = "swayimg.desktop";
      "image/bmp"          = "swayimg.desktop";
      "image/tiff"         = "swayimg.desktop";
      "image/svg+xml"      = "swayimg.desktop";
      "image/x-icon"       = "swayimg.desktop";
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
      "application/pdf"    = "okular.desktop";
    };
    associations.removed = {
      "audio/x-opus+ogg" = "org.kde.elisa.desktop";
    };
  };
  xdg.configFile."mimeapps.list".force = true;

  xdg.configFile = {
    "zathura/zathurarc".text = "set selection-clipboard clipboard\n";

    "swayimg/config".text = ''
      [list]
      all = yes

      [keys.viewer]
      Left = prev_file
      Right = next_file
      d = exec hyprctl dispatch 'hl.dsp.exec_cmd("trash-put \"%\"")'; skip_file
      u = exec bash -c 'echo 0 | trash-restore'
      Period = zoom +10
    '';

    "mako/config".text = ''
      background-color=#1a1a1a
      text-color=#e6e1e1
      border-color=#49464a
      border-size=1
      border-radius=10
      padding=12
      margin=8

      font=Google Sans Flex 12
      max-icon-size=32
      icon-path=/usr/share/icons/hicolor

      default-timeout=5000
      ignore-timeout=0
      max-visible=5

      layer=overlay
      anchor=top-right

      [urgency=low]
      border-color=#49464a
      default-timeout=3000

      [urgency=normal]
      border-color=#49464a

      [urgency=high]
      border-color=#ffb4ab
      text-color=#ffdad6
      default-timeout=0

      [mode=do-not-disturb]
      invisible=1
    '';

    "fastfetch/config.jsonc".text = ''
      {
        "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
        "modules": [
          "title",
          "separator",
          "os",
          "host",
          "kernel",
          "uptime",
          "packages",
          "shell",
          "display",
          "de",
          "wm",
          "wmtheme",
          "terminal",
          "cpu",
          "gpu",
          "memory",
          "swap",
          "disk",
          "localip",
          "battery",
          "poweradapter",
          "break"
        ]
      }
    '';

    "fuzzel/fuzzel.ini".text = ''
      font=Google Sans Flex:weight=medium
      terminal=kitty -1
      prompt=">>  "
      layer=overlay

      [colors]
      background=131315ff
      text=e4e2e3ff
      selection=474648ff
      selection-text=c8c6c7ff
      border=474648dd
      match=c2c6d6ff
      selection-match=c2c6d6ff

      [border]
      radius=17
      width=1

      [dmenu]
      exit-immediately-if-empty=yes
    '';

    "tmux/tmux.conf".text = ''
      set  -g default-terminal "screen"
      set  -g base-index      0
      setw -g pane-base-index 0

      set -g status-keys emacs
      set -g mode-keys   emacs

      set  -g mouse             off
      set  -g focus-events      off
      setw -g aggressive-resize off
      setw -g clock-mode-style  12
      set  -s escape-time       10
      set  -g history-limit     2000

      set -g @plugin 'tmux-plugins/tpm'
      set -g @plugin 'tmux-plugins/tmux-resurrect'
      set -g @plugin 'tmux-plugins/tmux-continuum'

      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '10'

      run '~/.tmux/plugins/tpm/tpm'
    '';

    "fontconfig/fonts.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
          <match target="font">
              <edit name="rgba" mode="assign">
              <const>none</const>
          </edit>
        </match>
      </fontconfig>
    '';
  };

  systemd.user.services.touchpad-filter = {
    Unit = {
      Description = "Touchpad BTN_LEFT filter (drops stuck-click ELAN firmware bug)";
      After = [ "graphical-session.target" ];
      StartLimitIntervalSec = 120;
      StartLimitBurst = 5;
    };
    Service = {
      Type = "simple";
      ExecStart = "/usr/local/bin/touchpad-filter";
      Restart = "on-failure";
      RestartSec = "3";
      StandardOutput = "journal";
      StandardError = "journal";
      SyslogIdentifier = "touchpad-filter";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Auto-symlink everything from ~/dotfiles/.config/ except entries managed
  # by home-manager itself (systemd, mimeapps.list, fontconfig, doublecmd).
  # To add a new app: drop its config into ~/dotfiles/.config/ and rebuild.
  home.file = autoConfigEntries // {
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
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.gitconfig";

    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.claude/settings.json";

    # doublecmd: only track config files, not runtime files (history, tabs, sessions)
    ".config/doublecmd/doublecmd.xml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/doublecmd/doublecmd.xml";
    ".config/doublecmd/shortcuts.scf".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/doublecmd/shortcuts.scf";
    ".config/doublecmd/colors.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/doublecmd/colors.json";
    ".config/doublecmd/highlighters.xml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/doublecmd/highlighters.xml";
    ".config/doublecmd/multiarc.ini".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/doublecmd/multiarc.ini";
  };

}
