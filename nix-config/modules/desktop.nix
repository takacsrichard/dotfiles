{ config, pkgs, lib, ... }:
# let
#   # SDDM theme derivation — uncomment alongside the SDDM block below to roll back
#   sddm-sugar-candy = pkgs.stdenv.mkDerivation {
#     name = "sddm-sugar-candy";
#     src = ../../system/sddm-themes;
#     installPhase = ''
#       mkdir -p $out/share/sddm/themes/sugar-candy
#       cp -r . $out/share/sddm/themes/sugar-candy/
#     '';
#   };
# in
{
  services.xserver.enable = true;
  services.xserver.xkb = { layout = "hu"; variant = ""; };

  # SDDM (sugar-candy) — kept for easy rollback, swap comments to re-enable
  # services.displayManager.sddm = {
  #   enable = true;
  #   theme = "sugar-candy";
  #   extraPackages = [ pkgs.kdePackages.qt5compat ];
  #   package = lib.mkForce (pkgs.kdePackages.sddm.override {
  #     sddm-unwrapped = pkgs.kdePackages.sddm.unwrapped.overrideAttrs (old: {
  #       postInstall = (old.postInstall or "") + ''
  #         ln -sf $out/bin/sddm-greeter-qt6 $out/bin/sddm-greeter
  #       '';
  #     });
  #   });
  #   settings = {
  #     Theme = {
  #       CursorTheme = "GoogleDot-White";
  #       Font = "Noto Sans,10,-1,0,400,0,0,0,0,0,0,0,0,0,0,1";
  #     };
  #     Users = {
  #       MaximumUid = 60513;
  #       MinimumUid = 1000;
  #     };
  #   };
  # };

  # greetd + tuigreet (lightweight TUI greeter, replaces SDDM)
  # F2 = session list, F3 = session picker, remembers last user+session per user
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = ''
        ${pkgs.tuigreet}/bin/tuigreet \
          --time \
          --asterisks \
          --remember \
          --remember-user-session \
          --sessions ${config.services.displayManager.sessionData.desktops}/share/xsessions:${config.services.displayManager.sessionData.desktops}/share/wayland-sessions
      '';
      user = "greeter";
    };
  };
  # lib.mkForce risk: if another module also sets this with mkForce, last one wins silently
  services.displayManager.sddm.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = true;
  programs.hyprland.enable = true;
  programs.firefox.enable = true;

  fonts.packages = with pkgs; [
    material-symbols
    nerd-fonts.jetbrains-mono
  ];

  systemd.tmpfiles.rules = [
    "d /var/cache/tuigreet 0755 greeter greeter -"
  ];
}
