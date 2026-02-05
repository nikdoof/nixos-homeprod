{ config, lib, pkgs, ... }:
{
  # Support for Intel HD 530 graphics.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiIntel
      intel-media-driver
    ];
  };

}
