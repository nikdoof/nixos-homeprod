{ config, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../modules/doofnet
    ./services
    ./vms.nix
  ];

  boot.kernel.sysctl = {
    # forward network packets that are not destined for the interface on which they were received
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;
  };

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
  systemd.network.netdevs."10-br0" = {
    netdevConfig = {
      Name = "br0";
      Kind = "bridge";
    };
    bridgeConfig = {
      DefaultPVID = "none";
      VLANFiltering = "yes";
    };
  };

  # Enable VLAN defs
  doofnet.network.vlans = true;

  systemd.network.networks = {
    # Configure the bridge
    "10-br0" = {
      matchConfig.Name = "br0";
      networkConfig = {
        VLAN = [
          config.systemd.network.netdevs."10-vlan-private".netdevConfig.Name
          config.systemd.network.netdevs."10-vlan-hosted".netdevConfig.Name
        ];
        LinkLocalAddressing = "no";
        LLDP = "no";
        EmitLLDP = "no";
        IPv6AcceptRA = "no";
        IPv6SendRA = "no";
      };
      bridgeVLANs = [
        { VLAN = config.systemd.network.netdevs."10-vlan-private".vlanConfig.Id; }
        { VLAN = config.systemd.network.netdevs."10-vlan-hosted".vlanConfig.Id; }
      ];
    };

    # Create the lan interface on the bridge
    "10-vlan-private" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-private".netdevConfig.Name;
      networkConfig = {
        Address = [ "10.101.3.22/16" ];
        Gateway = "10.101.1.1";
        IPv6AcceptRA = true;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    # Bridge in eno1
    "10-eno1" = {
      matchConfig.Name = "eno1";

      networkConfig.Bridge = "br0";

      bridgeVLANs = [
        { VLAN = config.systemd.network.netdevs."10-vlan-private".vlanConfig.Id; }
        { VLAN = config.systemd.network.netdevs."10-vlan-hosted".vlanConfig.Id; }
      ];
    };

    # Private VLAN VMs
    "10-vm-101" = {
      matchConfig.Name = "vm-101-*";

      networkConfig.Bridge = "br0";

      bridgeVLANs = [
        {
          EgressUntagged = config.systemd.network.netdevs."10-vlan-private".vlanConfig.Id;
          PVID = config.systemd.network.netdevs."10-vlan-private".vlanConfig.Id;
        }
      ];
    };

    # Hosted VLAN VMs
    "10-vm-106" = {
      matchConfig.Name = "vm-106-*";

      networkConfig.Bridge = "br0";

      bridgeVLANs = [
        {
          EgressUntagged = config.systemd.network.netdevs."10-vlan-hosted".vlanConfig.Id;
          PVID = config.systemd.network.netdevs."10-vlan-hosted".vlanConfig.Id;
        }
      ];
    };
  };

  microvm.host.enable = true;

  # Bind Prometheus home folder to the NVMe.
  fileSystems."/var/lib/microvm" = {
    device = "/srv/data/microvm";
    options = [ "bind" ];
  };

  doofnet.server = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?
}
