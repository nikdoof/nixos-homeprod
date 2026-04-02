{
  inputs,
  ...
}:
{
  # HP Prodesk 600 G3 DM
  #
  # Intel Sky Lake platform, Q270, DDR4, PCIe 3.0, M2 4x, Intel HD Graphics 530
  # https://support.hp.com/us-en/drivers/hp-prodesk-600-g3-desktop-mini-pc/15257642

  imports = [
    "${inputs.nixos-hardware}/common/cpu/intel/skylake"
    "${inputs.nixos-hardware}/common/pc/ssd"
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };
}
