let
  richard = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJ+P9vVrcs/+sE0waSj0r6n27R+Ay20CQ+TvMbmZjKG";
  nixos   = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHgJXEIeGmiXHaF5VL2ud1QH9MF2krC2VB50RAsPGfyw";
  all     = [ richard nixos ];
in {
  "atvpn.conf.age".publicKeys    = all;
  "atvpn_pf.conf.age".publicKeys = all;
  "huvpn.conf.age".publicKeys    = all;
  "huvpn_pf.conf.age".publicKeys = all;
  "chinavpn.conf.age".publicKeys   = all;
  "hkvpn.conf.age".publicKeys      = all;
  "indiavpn.conf.age".publicKeys   = all;
  "nlvpn.conf.age".publicKeys      = all;
  "russianvpn.conf.age".publicKeys = all;
  "sgvpn.conf.age".publicKeys      = all;
  "skvpn.conf.age".publicKeys      = all;
  "swissvpn.conf.age".publicKeys   = all;
  "taiwanvpn.conf.age".publicKeys  = all;
  "usvpn.conf.age".publicKeys      = all;
  "icevpn.conf.age".publicKeys     = all;
  "javpn.conf.age".publicKeys      = all;
  "pavpn.conf.age".publicKeys      = all;
  "sevpn.conf.age".publicKeys      = all;
  "eduroam.age".publicKeys = all;
  "restic-password.age".publicKeys=all;
  "rclone-password.age".publicKeys=all;
  "gh-token.age".publicKeys = all;
}
