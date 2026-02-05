{ config, lib, pkgs, ... }:
{
  boot.kernelModules = [ "gasket" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    pkgs.linuxKernel.packages.linux_6_6.gasket
  ];

  environment.systemPackages = with pkgs; [
    libedgetpu # Coral TPU runtime
    pciutils
  ];

  services.udev.extraRules = ''
     # Coral TPU rules
     SUBSYSTEM=="usb", ATTRS{idVendor}=="1a6e", ATTRS{idProduct}=="089a", MODE="0666"
     SUBSYSTEM=="usb", ATTRS{idVendor}=="18d1", ATTRS{idProduct}=="9302", MODE="0666"
     SUBSYSTEM=="apex", MODE="0666"
   '';
}
