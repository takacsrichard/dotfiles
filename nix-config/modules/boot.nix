{ pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 5;
  boot.loader.timeout = 5;
  boot.loader.efi.canTouchEfiVariables = true;
  # Default (older, stable) kernel instead of linuxPackages_latest while
  # chasing the intermittent poweroff hang — rules bleeding-edge regressions
  # in or out. consoleLogLevel=1 keeps output clean; raise to 7 to see
  # kernel INFO messages ("reboot: Power down") when diagnosing shutdown hangs.
  boot.kernelPackages = pkgs.linuxPackages;
  boot.consoleLogLevel = 1;
  boot.kernelParams = [ "reboot=efi" "amd_iommu=off" ];
  boot.kernel.sysctl."net.ipv4.tcp_mtu_probing" = 1;
  boot.kernel.sysctl."vm.vfs_cache_pressure" = 50;
  boot.kernel.sysctl."vm.dirty_writeback_centisecs" = 6000;
  boot.kernel.sysfs = {
    bus.pci.devices."0000:03:00.4".power.control = "auto";
    bus.pci.devices."0000:03:00.3".power.control = "auto";
  };
}
