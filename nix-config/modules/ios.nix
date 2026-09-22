{ pkgs, ... }:
{
  # iPhone/iOS device access over USB (mount with ifuse, e.g. for photo transfer)
  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse
  ];
}
