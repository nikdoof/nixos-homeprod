_:
let
  hostName = "ns-02";
  domainName = "int.doofnet.uk";
in
{
  doofnet.microvm = {
    enable = true;
    cid = 13;
    vlan = "101";
  };

  # Networking
  networking.useDHCP = false;
  networking.hostName = hostName;
  networking.nameservers = [
    "127.0.0.1"
    "10.101.1.2"
    "10.101.1.3"
  ];
  networking.domain = domainName;
  networking.search = [ domainName ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig = {
      Address = [
        "10.101.1.3/16"
        "2001:8b0:bd9:101::3/64"
        "fddd:d00f:dab0:101::3/64"
      ];
      Gateway = "10.101.1.1";
      IPv6AcceptRA = true;
      DHCP = "no";
    };
    dhcpV6Config.UseDelegatedPrefix = false;
  };

  doofnet.server = true;

  doofnet.bind = {
    enable = true;
    mode = "secondary";
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
