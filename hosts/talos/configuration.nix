{
  pkgs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/p8-laptop.nix
    ../../modules/common.nix
  ];

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };

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

  environment.systemPackages = with pkgs; [
    kitty
    ghostty
    chafa
  ];

  programs.zsh.shellAliases = {
    startx = "uwsm start default"; # Old habits die hard
  };
}
