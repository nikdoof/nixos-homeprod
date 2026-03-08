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

  # Configure the Pi's RTC
  systemd.services.pi-rtc = {
    unitConfig = {
      Description = "Configure and read the RTC on the I2C bus";
      Before = "basic.target";
      Conflicts = "shutdown.target";
      DefaultDependencies = "no";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "/bin/sh -c \"modprobe i2c_bcm2835 && modprobe rtc_ds1307 && sleep 1 && echo ds1307 0x68 > /sys/class/i2c-dev/i2c-1/device/new_device && hwclock -s\"";
      ExecStop = "hwclock -w";
      RemainAfterExit = "yes";
    };
    wantedBy = [ "basic.target" ];
  };
}
