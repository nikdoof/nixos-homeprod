{ config, ... }:

{
  imports = [
    ../../hardware/prodesk-600-g3-dm.nix
    ./hardware-configuration.nix
    ./services
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "gw";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;

  # WAN: eno2 → VLAN 911 → ppp0 (PPPoE to CityFibre ONT)
  systemd.network.netdevs."05-vlan-wan" = {
    netdevConfig = {
      Name = "vlan-wan";
      Kind = "vlan";
    };
    vlanConfig.Id = 911;
  };

  systemd.network.networks = {
    # Internal VLANs on eno1
    "10-eno1" = {
      matchConfig.Name = "eno1";
      networkConfig.VLAN = [
        config.systemd.network.netdevs."10-vlan-private".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-public".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-lab".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-ha".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-hosted".netdevConfig.Name
      ];
    };

    "10-vlan-private" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-private".netdevConfig.Name;
      networkConfig.Address = [
        "10.101.1.1/16"
        "2001:8b0:bd9:101::1/64"
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    "10-vlan-public" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-public".netdevConfig.Name;
      networkConfig.Address = [
        "10.102.1.1/16"
        "2001:8b0:bd9:102::1/64"
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    "10-vlan-lab" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-lab".netdevConfig.Name;
      networkConfig.Address = [
        "10.104.1.1/16"
        "2001:8b0:bd9:104::1/64"
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    "10-vlan-ha" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-ha".netdevConfig.Name;
      networkConfig.Address = [
        "10.105.1.1/16"
        "2001:8b0:bd9:105::1/64"
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    # Hosted VLAN uses a publicly routable /29 block (not NATed)
    "10-vlan-hosted" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-hosted".netdevConfig.Name;
      networkConfig.Address = [
        "217.169.25.9/29"
        "2001:8b0:bd9:106::1/64"
      ];
      linkConfig.RequiredForOnline = "routable";
    };

    # WAN — eno2 carries VLAN 911 to the CityFibre ONT; pppd creates ppp0 over it
    "05-eno2" = {
      matchConfig.Name = "eno2";
      networkConfig.VLAN = [ "vlan-wan" ];
    };

    "05-vlan-wan" = {
      matchConfig.Name = "vlan-wan";
      networkConfig.LinkLocalAddressing = "no";
    };

    # ppp0 is created by pppd; networkd applies IPv6 RA acceptance.
    # systemd-networkd sets accept_ra=2 so RA works despite global forwarding.
    "30-ppp0" = {
      matchConfig.Name = "ppp0";
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  doofnet.network.vlans = true;
  doofnet.server = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
