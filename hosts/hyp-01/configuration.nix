{ ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../modules/doofnet
    ./services
    ./vms
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "hyp-01";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;

  # Create the bridge dev
  systemd.network.netdevs."br0" = {
    netdevConfig = {
      Name = "br0";
      Kind = "bridge";
    };
  };

  systemd.network.networks = {
    # Bridge the ethernet and all vm TAPs
    "10-bridge" = {
      matchConfig.Name = [
        "eno1"
        "vm-*"
      ];
      networkConfig = {
        Bridge = "br0";
      };
    };

    # Create the lan interface on the bridge
    "10-lan" = {
      matchConfig.Name = "br0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };

  doofnet.server = true;
  doofnet.network.vlans = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
