{
  inputs,
  ...
}:
{
  # HP Prodesk 400 G4 SFF
  #
  # Intel Kaby Lake platform, H270, DDR4, PCIe 3.0
  # https://support.hp.com/gb-en/product/details/model/15292381

  imports = [
    inputs.nixos-hardware.nixosModules.common-gpu-intel-kaby-lake
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };
}
