{ config, lib, ... }:
with lib;
{
  options.doofnet.network.vlans = mkEnableOption "Create Doofnet VLAN netdevs in systemd-networkd";

  config = mkIf config.doofnet.network.vlans {
    systemd.network.netdevs = {
      "vlan-private" = {
        netdevConfig = {
          Name = "vlan-private";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 101;
        };
      };

      "vlan-lab" = {
        netdevConfig = {
          Name = "vlan-private";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 104;
        };
      };

      "vlan-hosted" = {
        netdevConfig = {
          Name = "vlan-private";
          Kind = "vlan";
        };
        vlanConfig = {
          Id = 106;
        };
      };
    };
  };
}
