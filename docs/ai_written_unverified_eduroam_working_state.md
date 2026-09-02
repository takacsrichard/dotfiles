# eduroam — known-working state (captured 2026-09-02, 07:14 boot)

Verified working: connected at boot, EAP-SUCCESS in journal, IP 10.10.5.119,
WU DNS 137.208.10.20 / 137.208.20.30, search domain wu.ac.at.

## Why it broke before (root cause)

NixOS 26.05 hardens wpa_supplicant with systemd `ProtectHome=true` — the daemon
**cannot read anything under /home**. The CAT installer put the CA cert at
`~/.config/cat_installer/ca.pem`; wpa_supplicant failed to load it
(`OpenSSL: tls_connection_ca_cert ... No such file or directory`), TLS died
before credentials were ever sent, and NetworkManager misreported it as
"Secrets were required, but not provided". Same failure on Hyprland and KDE
because it's the same daemon. Documented on the
[NixOS wiki eduroam page](https://wiki.nixos.org/wiki/Eduroam): certs must
live in `/etc/ssl/certs` or `/etc/wpa_supplicant`.

## The fix that made it work (applied 2026-09-01 23:59)

CA cert copied to a path wpa_supplicant is allowed to read:

- `/etc/ssl/certs/eduroam/ca.pem` — root:root, mode 644
- sha256: `be81d014152298ac41a5f7edde936ee76ef64f8ddd0150c3ee02c52629dcfe17`
- identical copies: `~/.config/cat_installer/ca.pem` (CAT installer original) and
  `~/dotfiles/nix-config/certs/wu-eduroam-ca.pem` (committed backup)

## Working NetworkManager profile

File: `/etc/NetworkManager/system-connections/eduroam.nmconnection`
(root-only, **contains the WiFi password in plaintext** — do NOT copy it into
dotfiles). UUID `e0ca8591-5948-3c69-8474-f35bc56aff0d`.

Full sanitized dump of every profile setting (secrets shown as `<hidden>`):
[eduroam-profile-snapshot.txt](eduroam-profile-snapshot.txt), captured
2026-09-02 while connected and working. Key settings:

```
802-11-wireless-security.key-mgmt = wpa-eap
802-1x.eap                 = peap
802-1x.phase2-auth         = mschapv2
802-1x.identity            = h12313036@wu.ac.at      # @wu.ac.at, NOT @s.wu.ac.at (that's VPN)
802-1x.anonymous-identity  = h12313036@wu.ac.at
802-1x.ca-cert             = /etc/ssl/certs/eduroam/ca.pem   # MUST be outside /home
802-1x.altsubject-matches  = DNS:radius.wu.ac.at,DNS:radius1.wu.ac.at,DNS:radius2.wu.ac.at
802-1x.system-ca-certs     = no
802-1x.password-flags      = 0   # password stored in the file itself, no agent needed
connection.autoconnect     = yes
```

Password = WU account password (changed server-side per WU on 26.08.2026).

## If it breaks again, check in this order

1. `journalctl -b --no-pager | grep -iE "CTRL-EVENT-EAP|ca_cert"` — look for
   `EAP-SUCCESS` vs `Failed to load root certificates`.
2. Does `/etc/ssl/certs/eduroam/ca.pem` still exist with the sha256 above?
   If gone (e.g. after some rebuild/cleanup):
   `sudo mkdir -p /etc/ssl/certs/eduroam && sudo cp ~/.config/cat_installer/ca.pem /etc/ssl/certs/eduroam/ca.pem && sudo chmod 644 /etc/ssl/certs/eduroam/ca.pem`
3. Does the profile still point there?
   `nmcli connection show eduroam | grep ca-cert`
4. If the profile itself is gone, recreate with the settings above
   (`nmcli connection add type wifi con-name eduroam ssid eduroam ...`) and
   re-enter the password — never bake it into configuration.nix.

## Optional hardening (not applied)

To make the cert survive anything, manage it declaratively in
configuration.nix (the cert is public, not a secret):

```nix
environment.etc."ssl/certs/eduroam/ca.pem".source = ./certs/wu-eduroam-ca.pem;
```

(copy `~/.config/cat_installer/ca.pem` into the nix-config repo as
`certs/wu-eduroam-ca.pem` first).

## Working RADIUS chain seen in journal (for reference)

```
depth=0 CN=radius1.wu.ac.at  ← matched altsubject DNS:radius1.wu.ac.at
depth=1 Sectigo Public Server Authentication CA DV R36
depth=2 Sectigo Public Server Authentication Root R46
depth=3 USERTrust RSA Certification Authority
CTRL-EVENT-EAP-SUCCESS
```
