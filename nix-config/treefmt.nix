{
  projectRootFile = "flake.nix";

  programs.nixfmt.enable = true;
  programs.statix.enable = true;
  programs.deadnix.enable = true;

  settings.global.excludes = [
    "result"
    "result-*"
    "secrets/*.age"
    "patches/*.patch"
    "flake.lock"
  ];
}
