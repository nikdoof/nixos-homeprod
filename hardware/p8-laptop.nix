{
  ...
}:

{
  # Extra kernel modules
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usbhid"
    "thunderbolt"
  ];

  # Fix on boot framebuffer res and rotation
  boot.kernelParams = [
    "video=efifb:mode=0"
    "video=DSI-1:panel_orientation=right_side_up"
    "fbcon=rotate:1"
  ];
  boot.extraModprobeConfig = ''
    options intel_hid enable_sw_tablet_mode=2
  '';

  # Fix the font rendering
  fonts.fontconfig = {
    subpixel.rgba = "vbgr"; # Pixel order for rotated screen
  };

  # The keyboard is US layout
  services.xserver.xkb.layout = "us";

  # Enable sensors
  hardware.sensor.iio.enable = true;
  services.udev.extraHwdb = ''
    sensor:modalias:acpi:BOSC0200*:dmi:*
      ACCEL_MOUNT_MATRIX=0, -1, 0; -1, 0, 0; 0, 0, 1
  '';
  services.acpid.enable = true;

  # Enable sound.
  services.pulseaudio.enable = true;

  # Enable touch input
  services.libinput.enable = true;

  # Enable some standard services
  services = {
    upower.enable = true;
    thermald.enable = true;
    fwupd.enable = true;
    smartd.enable = true;
  };
}
