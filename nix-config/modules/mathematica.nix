{ pkgs, ... }:
{
  environment.systemPackages = [
    ((pkgs.mathematica.override {
      versionInfo = {
        version = "15.0.1";
        lang = "en";
        language = "English";
        installer = "Wolfram_15.0.1.sh";
        hash = "sha256-VzK8CuOhk4sOO5CL4z3rfpY5631F2RN6c0Dh8cExeeg=";
      };
    }).overrideAttrs (old: {
      # CURLLink/libcurllink.so ships its own self-consistent libcurl.so right
      # next to it, which resolves fine on its own. But nix-ld's global
      # LD_LIBRARY_PATH (programs.nix-ld) takes priority over Mathematica's
      # RUNPATH and shadows it with a different curl build that needs
      # libnghttp3.so.9, which isn't anywhere in Mathematica's search path -
      # breaking the whole dlopen chain. Prepend CURLLink's own lib dir so it
      # wins over nix-ld's.
      preFixup = old.preFixup + ''
        for bin in $out/libexec/Mathematica/Executables/*; do
          wrapProgram "$bin" --prefix LD_LIBRARY_PATH : "$out/libexec/Mathematica/SystemFiles/Links/CURLLink/LibraryResources/Linux-x86-64"
        done
      '';
    }))
  ];
}
