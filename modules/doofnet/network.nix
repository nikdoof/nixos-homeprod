{ config, lib, ... }:
{
  options.doofnet.network.vlans = lib.mkEnableOption "Create Doofnet VLAN netdevs in systemd-networkd";

  config = lib.mkIf config.doofnet.network.vlans {
    systemd.network.netdevs = {
      "10-vlan-private" = {
        netdevConfig = {
          Name = "vlan-private";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 101;
        };
      };

      "10-vlan-lab" = {
        netdevConfig = {
          Name = "vlan-lab";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 104;
        };
      };

      "10-vlan-hosted" = {
        netdevConfig = {
          Name = "vlan-hosted";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 106;
        };
      };
    };
  };
}
