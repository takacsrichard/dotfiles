{ config, pkgs, ... }:
{
  networking.hostName = "nixos";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openconnect ];
  };
  networking.networkmanager.dns = "systemd-resolved";

  # nm still connects in the background regardless -- this just stops boot
  # (and the login prompt) from waiting up to 2min for "online" to show up,
  # which matters most with no wifi around (eduroam-less middle of nowhere)
  systemd.services.NetworkManager-wait-online.enable = false;

  age.secrets."eduroam" = {
    file = ../../secrets/eduroam.age;
    mode = "0600";
  };

  environment.etc."ssl/certs/eduroam/ca.pem".source = ../certs/wu-eduroam-ca.pem;

  networking.networkmanager.ensureProfiles = {
    environmentFiles = [ config.age.secrets."eduroam".path ];
    profiles.eduroam = {
      connection = {
        id = "eduroam";
        type = "wifi";
      };
      wifi = {
        mode = "infrastructure";
        ssid = "eduroam";
      };
      wifi-security = {
        key-mgmt = "wpa-eap";
      };
      "802-1x" = {
        eap = "peap;";
        identity = "h12313036@wu.ac.at";
        anonymous-identity = "h12313036@wu.ac.at";
        ca-cert = "/etc/ssl/certs/eduroam/ca.pem";
        altsubject-matches = "DNS:radius.wu.ac.at;DNS:radius1.wu.ac.at;DNS:radius2.wu.ac.at";
        phase2-auth = "mschapv2";
        password = "$EDUROAM_PASSWORD";
        password-flags = "0";
      };
      ipv4 = {
        method = "auto";
      };
      ipv6 = {
        method = "auto";
      };
    };
  };

  services.resolved.enable = true;

  environment.systemPackages = with pkgs; [
    wireguard-tools
    iw
  ];
}
