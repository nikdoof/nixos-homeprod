{
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../hardware/coral-tpu-pcie.nix
    ../../modules/common.nix
    ../../modules/server.nix
    ../../modules/podman.nix
    ../../modules/traefik.nix
    ./containers.nix
    ./timers.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };

  # Networking
  networking.useDHCP = false;
  networking.hostName = "svc-01"; # Define your hostname.
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  # Media
  fileSystems."/mnt/nas-03/media" = {
    device = "nas-03.int.doofnet.uk:/mnt/media";
    fsType = "nfs";
    options = [
      "rw"
      "noatime"
      "nfsvers=4"
      "proto=tcp"
    ];
  };

  # Printing
  services.printing = {
    enable = true;
    openFirewall = true;
    defaultShared = true;
    browsing = true;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
