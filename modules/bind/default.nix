{
  config,
  lib,
  inputs,
  ...
}:
let
  bindCfg = config.doofnet.bind;
in
{
  options.doofnet.bind = {
    enable = lib.mkEnableOption "BIND DNS server";

    mode = lib.mkOption {
      type = lib.types.enum [
        "primary"
        "slave"
      ];
      default = "primary";
      description = "Whether this server acts as a primary (master) or slave (secondary) DNS server";
    };
  };

  config = lib.mkIf bindCfg.enable {
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    services.bind = {
      enable = true;

      cacheNetworks = [
        "10.0.0.0/8"
        "2001:8b0:bd9::/48"
        "fddd:d00f:dab0::/48"
      ];

      extraConfig = ''
        // Stats channel for prometheus-bind-exporter
        statistics-channels {
          inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
        };

        // HE.net DNS Servers
        acl "he-dns" {
            216.218.133.2;
            2001:470:600::2;
        };

        // DHCP update key placeholder
        // acl "doofnet-dhcp-updates" { ... };
      '';

      zones =
        let
          allZones = import ./zones { dns = inputs.dns; };
          dns_masters = [ "10.101.1.2" ];

          # Ensure all zones have required attributes for the BIND module
          normalizeZone =
            name: zone:
            zone
            // {
              # Add masters = [] if not present (required by NixOS bind module)
              masters = if zone ? masters then zone.masters else [ ];
              # Add slaves if not present (required by NixOS bind module)
              slaves = if zone ? slaves then zone.slaves else [ ];
            };
        in
        if bindCfg.mode == "slave" then
          # For slave mode, convert all zones to slave zones
          builtins.mapAttrs (
            name: zone:
            (normalizeZone name zone)
            // {
              master = false;
              # Slave zones fetch from these masters
              masters = dns_masters;
              # Slave zones don't need the file content, BIND will fetch it
              file = "/var/lib/bind/zones/${name}.zone";
              # Remove extraConfig which may contain allow-update (not valid for slaves)
              extraConfig = "";
            }
          ) allZones
        else
          # For primary mode, normalize zones to ensure all required attributes exist
          builtins.mapAttrs normalizeZone allZones;
    };

    services.prometheus.exporters.bind = {
      enable = true;
      openFirewall = true;
    };

    # Create zone directory for slave zones
    systemd.tmpfiles.rules = lib.mkIf (bindCfg.mode == "slave") [
      "d /var/lib/bind/zones 0755 named named -"
    ];
  };
}
