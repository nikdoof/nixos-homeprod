{ ... }:
{
  # Pi3 boot configuration.
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  hardware.enableRedistributableFirmware = true;
  networking.wireless.enable = true;

  boot.initrd.kernelModules = [
    "vc4"
    "bcm2835_dma"
    "i2c_bcm2835"
  ];
}
