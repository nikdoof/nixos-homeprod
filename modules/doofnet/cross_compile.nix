{ lib, config, ... }:
with lib;
{
  options.doofnet.cross_compile = mkEnableOption "Enable emulation for cross-compiling";

  config = mkIf config.doofnet.cross_compile {
    # Allows for cross compling for Pis
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    nix.settings.extra-platforms = [
      "aarch64-linux"
      "arm-linux"
    ];
  };
}
