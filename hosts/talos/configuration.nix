{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-hidpi
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    ./hardware-configuration.nix
    ../../hardware/p8-laptop.nix
    ../../modules/doofnet
  ];

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

  networking.hostName = "talos";
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;
  services.fstrim.enable = true;

  services.logind.settings.Login = {
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true; # recommended for most users
    xwayland.enable = true; # Xwayland can be disabled.
  };
  programs.hyprlock.enable = true;
  programs.waybar.enable = true;
  programs.yazi.enable = true;

  environment.systemPackages = with pkgs; [
    kitty
    ghostty
    chafa
    rofi
    hyprpaper
    font-awesome
  ];

  programs.zsh.shellAliases = {
    startx = "uwsm start default"; # Old habits die hard
  };
}
