{
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/raspberry-pi-3.nix
    ../../modules/doofnet
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "ns-01";
  networking.nameservers = [
    "127.0.0.1"
    "10.101.1.2"
    "10.101.1.3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.1.2/16"
        "2001:8b0:bd9:101::2/64"
        "fddd:d00f:dab0:101::2/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
  };

  doofnet.server = true;

  doofnet.bind = {
    enable = true;
    mode = "primary";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
