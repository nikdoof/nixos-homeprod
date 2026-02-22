{
  ...
}:

{
  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };

  boot.initrd.availableKernelModules = [
    "ata_piix"
    "mptspi"
    "sd_mod"
    "sr_mod"
  ];

  virtualisation.vmware.guest.enable = true;
}
