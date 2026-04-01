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

  # WAN: enp3s0f1 → VLAN 911 → ppp0 (PPPoE to CityFibre ONT)
  systemd.network.netdevs."05-vlan-wan" = {
    netdevConfig = {
      Name = "vlan-wan";
      Kind = "vlan";
    };
    vlanConfig.Id = 911;
  };

  systemd.network.networks = {
    # On-board management interface. AddPrefixRoute=false suppresses the
    # auto-generated subnet route so vlan-private (metric 0) is always
    # preferred. Explicit routes at metric 2048 are added as fallback — if
    # vlan-private goes down these take over, restoring reachability via enp2s0.
    "10-enp2s0" = {
      matchConfig.Name = "enp2s0";
      addresses = [
        {
          Address = "10.101.3.23/16";
          AddPrefixRoute = false;
        }
        {
          Address = "2001:8b0:bd9:101::3:23/64";
          AddPrefixRoute = false;
        }
      ];
      routes = [
        {
          Destination = "10.101.0.0/16";
          Metric = 2048;
          Scope = "link";
        }
        {
          Destination = "2001:8b0:bd9:101::/64";
          Metric = 2048;
        }
      ];
      # gw is the router — never accept RAs on the management interface.
      # Without this, gw installs its own radvd RA as a default route via
      # enp2s0 (metric 512, pref high) which beats the ppp0 default and loops.
      networkConfig.IPv6AcceptRA = false;
      linkConfig.RequiredForOnline = "no";
    };

    # Internal VLANs on enp3s0f0 — trunk port carries no addresses itself
    "10-enp3s0f0" = {
      matchConfig.Name = "enp3s0f0";
      linkConfig.RequiredForOnline = "no";
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
    };

    "10-vlan-public" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-public".netdevConfig.Name;
      networkConfig.Address = [
        "10.102.1.1/16"
        "2001:8b0:bd9:102::1/64"
      ];
    };

    "10-vlan-lab" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-lab".netdevConfig.Name;
      networkConfig.Address = [
        "10.104.1.1/16"
        "2001:8b0:bd9:104::1/64"
      ];
    };

    "10-vlan-ha" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-ha".netdevConfig.Name;
      networkConfig.Address = [ "10.105.1.1/16" ];
    };

    # Hosted VLAN uses a publicly routable /29 block (not NATed)
    "10-vlan-hosted" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-hosted".netdevConfig.Name;
      networkConfig.Address = [
        "217.169.25.9/29"
        "2001:8b0:bd9:106::1/64"
      ];
    };

    # WAN — enp3s0f1 carries VLAN 911 to the CityFibre ONT; pppd creates ppp0 over it
    "05-enp3s0f1" = {
      matchConfig.Name = "enp3s0f1";
      linkConfig.RequiredForOnline = "no";
      networkConfig.VLAN = [ "vlan-wan" ];
    };

    "05-vlan-wan" = {
      matchConfig.Name = "vlan-wan";
      linkConfig.RequiredForOnline = "no";
      networkConfig.LinkLocalAddressing = "no";
    };

    # ppp0 is created by pppd. AAISP assigns the WAN IPv6 address via DHCPv6
    # IA_NA but never sends an RA over PPP, so WithoutRA=solicit forces the
    # DHCPv6 client to send a Solicit immediately on link-local assignment
    # rather than waiting for an RA with M/O flags.
    # IPv6AcceptRA=true keeps accept_ra=2 in the kernel (required for RA
    # processing on VLANs despite global IPv6 forwarding being enabled).
    "30-ppp0" = {
      matchConfig.Name = "ppp0";
      networkConfig = {
        DHCP = "ipv6";
        IPv6AcceptRA = true;
      };
      dhcpV6Config = {
        UseDNS = "no";
        WithoutRA = "solicit";
      };
      ipv6AcceptRAConfig = {
        UseDNS = "no";
        DHCPv6Client = "always";
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  # Only the internal VLAN interfaces are required to be online before
  # network-online.target is reached. WAN/management/trunk interfaces are
  # excluded so ppp0 coming up late doesn't block kea, radvd, and other services.

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

  doofnet.network.vlans = true;
  doofnet.server = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
