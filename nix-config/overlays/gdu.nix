final: prev: {
  gdu = prev.gdu.overrideAttrs (old: {
    patches = (old.patches or []) ++ [ ../../patches/gdu-hotkeys.patch ];
    doCheck = false;
  });
}
