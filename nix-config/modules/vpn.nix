{ config, ... }:
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
    after            = [ "graphical.target" ];
    wantedBy         = [ "graphical.target" ];
    restartIfChanged = false;
    stopIfChanged    = false;
  };
}
