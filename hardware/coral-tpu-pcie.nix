{
  pkgs,
  ...
}:
{
  boot.kernelModules = [
    "gasket"
    "apex"
  ];
  boot.extraModulePackages = [
    pkgs.linuxKernel.packages.linux_6_12.gasket
  ];

  environment.systemPackages = with pkgs; [
    libedgetpu # Coral TPU runtime
    pciutils
  ];

  services.udev.extraRules = ''
    # Coral TPU rules
    SUBSYSTEM=="apex", MODE="0666"
  '';
}
