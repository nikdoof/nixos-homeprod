{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../hardware/prodesk-600-g3-dm.nix
      ../../hardware/coral-tpu-pcie.nix
      ../../modules/common.nix
      ../../modules/server.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };

  # Networking
  networking.hostName = "svc-01"; # Define your hostname.
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Media
  fileSystems."/mnt/nas-03/media" = {
    device = "nas-03.int.doofnet.uk:/mnt/media";
    fsType = "nfs";
    options = [ "rw" "noatime" "nfsvers=4" "proto=tcp" ];
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
