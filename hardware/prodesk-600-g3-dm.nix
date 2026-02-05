{ config, lib, pkgs, ... }:
{
  # Support for Intel HD 530 graphics.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver
      intel-media-driver
    ];
  };

}
