{
  config,
  pkgs,
  ...
}:
{
  boot.kernelModules = [
    "gasket"
    "apex"
  ];
  boot.extraModulePackages = with config.boot.kernelPackages; [
    gasket
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
