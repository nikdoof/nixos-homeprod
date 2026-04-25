{
  inputs,
  ...
}:
{
  # HP Prodesk 400 G4 SFF
  #
  # Intel Kaby Lake platform, H270, DDR4, PCIe 3.0, Intel HD Graphics 630
  # https://support.hp.com/gb-en/product/details/model/15292381

  imports = [
    "${inputs.nixos-hardware}/common/cpu/intel/kaby-lake"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };

  # Intel thermal management for compact SFF form factor
  services.thermald.enable = true;

  # No Bluetooth or WiFi hardware present; prevent the kernel loading these
  boot.blacklistedKernelModules = [
    "bluetooth"
    "cfg80211"
  ];
}
