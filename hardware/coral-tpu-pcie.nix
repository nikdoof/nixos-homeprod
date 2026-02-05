{ config, lib, pkgs, ... }:
{
  boot.kernelModules = [ "gasket" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    pkgs.linuxKernel.packages.linux_6_12.gasket
  ];

  environment.systemPackages = with pkgs; [
    libedgetpu # Coral TPU runtime
    pciutils
  ];
}
