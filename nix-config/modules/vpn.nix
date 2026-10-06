{ config, pkgs, lib, ... }:
let
  vpnBypassCidrs = [
    "137.208.0.0/16"  # wu.ac.at (AS1776)
    "99.84.91.0/24"   # canvas.wu.ac.at -> wu-vanity.instructure.com (CloudFront range A)
    "65.9.130.0/24"   # canvas.wu.ac.at -> wu-vanity.instructure.com (CloudFront range B)
    "193.22.104.0/23" # willhaben.at (AS34798)
    "207.241.224.2"   # archive.org
    "207.241.237.3"   # web.archive.org
  ];
 # TODO
  bypassAddScript = pkgs.writeShellScript "atvpn-bypass-add" ''
    for cidr in ${lib.concatStringsSep " " vpnBypassCidrs}; do
      ip rule add to "$cidr" table main priority 100 || true
    done
    resolvectl revert atvpn || true
  '';

  bypassDelScript = pkgs.writeShellScript "atvpn-bypass-del" ''
    for cidr in ${lib.concatStringsSep " " vpnBypassCidrs}; do
      ip rule del to "$cidr" table main priority 100 || true
    done
  '';
in
{
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" "/etc/ssh/ssh_host_rsa_key" ];

  age.secrets."atvpn.conf"    = { file = ../../secrets/atvpn.conf.age;    mode = "0600"; };
  age.secrets."atvpn_pf.conf" = { file = ../../secrets/atvpn_pf.conf.age; mode = "0600"; };
  age.secrets."huvpn.conf"    = { file = ../../secrets/huvpn.conf.age;     mode = "0600"; };
  age.secrets."huvpn_pf.conf" = { file = ../../secrets/huvpn_pf.conf.age;  mode = "0600"; };

  networking.wg-quick.interfaces = {
    atvpn    = { autostart = false; configFile = config.age.secrets."atvpn.conf".path; };
    atvpn_pf = { autostart = false; configFile = config.age.secrets."atvpn_pf.conf".path; };
    huvpn    = { autostart = false; configFile = config.age.secrets."huvpn.conf".path; };
    huvpn_pf = { autostart = false; configFile = config.age.secrets."huvpn_pf.conf".path; };
  };

  systemd.services."wg-quick-atvpn" = {
    restartIfChanged = false;
    stopIfChanged    = false;
    serviceConfig = {
      ExecStartPost = "${bypassAddScript}";
      ExecStopPre   = "${bypassDelScript}";
    };
  };
}
