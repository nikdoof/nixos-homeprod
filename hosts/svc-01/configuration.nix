{
  pkgs,
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
    ../../modules/nfs/media.nix
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

  # Printing
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      userServices = true;
    };
    extraServiceFiles = {
      zebra = ./cups/AirPrint-Zebra_GK420d.service;
    };
  };

  services.printing = {
    enable = true;
    openFirewall = true;
    defaultShared = true;
    browsing = false;
    listenAddresses = [ "10.101.3.20:631" ];
    allowFrom = [ "all" ];

    drivers = [
      (pkgs.writeTextDir "share/cups/model/Zebra_GK420d.ppd" (builtins.readFile ./cups/Zebra_GK420d.ppd))
    ];
  };

  hardware.printers = {
    ensurePrinters = [
      {
        name = "Zebra_GK420d";
        description = "Zebra GK420d";
        location = "Games Room";
        deviceUri = "usb://Zebra%20Technologies/ZTC%20GK420d?serial=28J120703625";
        model = "Zebra_GK420d.ppd";

        ppdOptions = {
          PageSize = "6.00x4.00";
        };
      }
    ];
    ensureDefaultPrinter = "Zebra_GK420d";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
