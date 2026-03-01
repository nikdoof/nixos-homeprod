{
  config,
  lib,
  pkgs,
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

    age.secrets = {
      digitaloceanApiToken = {
        file = ../../secrets/doofnetDnsUpdateKey.age;
        owner = "named";
      };
    };

    services.bind = {
      enable = true;

      forwarders = [ ];
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

        // DHCP update key
        include "${config.age.secrets.digitaloceanApiToken.path}";
        acl "doofnet-dhcp-updates" {
            key doofnet-dhcp-updates;
        };
      '';

      zones =
        let
          allZones = import ./zones { dns = inputs.dns; };
          dns_masters = [ "10.101.1.2" ];
          dnsUtils = inputs.dns.util.${pkgs.system};

          # Ensure all zones have required attributes for the BIND module
          normalizeZone =
            name: zone:
            let
              baseZone = zone // {
                # Add masters = [] if not present (required by NixOS bind module)
                masters = if zone ? masters then zone.masters else [ ];
                # Add slaves if not present (required by NixOS bind module)
                slaves = if zone ? slaves then zone.slaves else [ ];
                # Add extraConfig if not present
                extraConfig = if zone ? extraConfig then zone.extraConfig else "";
              };
              # If extraConfig contains allow-transfer, we need to merge slaves into it
              hasAllowTransfer = builtins.match ".*allow-transfer.*" baseZone.extraConfig != null;
              # Check if extraConfig contains allow-update
              hasAllowUpdate = builtins.match ".*allow-update.*" baseZone.extraConfig != null;
              mergedExtraConfig =
                if hasAllowTransfer && (builtins.length baseZone.slaves) > 0 then
                  # Replace "allow-transfer {" with "allow-transfer { <slaves>;"
                  let
                    slavesIPs = builtins.concatStringsSep "; " (baseZone.slaves ++ [ "" ]);
                  in
                  builtins.replaceStrings [ "allow-transfer {" ] [ "allow-transfer { ${slavesIPs}" ]
                    baseZone.extraConfig
                else
                  baseZone.extraConfig;
              # Convert file string to path using writeZone if it's a string
              # For master zones with allow-update, use writable directory
              zoneFile =
                if builtins.isString baseZone.file then
                  # Write zone to /nix/store first
                  let
                    storeFile = pkgs.writeText "${name}.zone" baseZone.file;
                  in
                  # For master zones with allow-update, use writable location
                  if baseZone.master && hasAllowUpdate then "/var/lib/bind/zones/${name}.zone" else storeFile
                else
                  baseZone.file;
            in
            baseZone
            // {
              file = zoneFile;
              extraConfig = mergedExtraConfig;
              # Clear slaves list if allow-transfer is in extraConfig to avoid duplicate directive
              slaves = if hasAllowTransfer then [ ] else baseZone.slaves;
            };

          # Build a list of zones needing dynamic updates with their store files
          dynamicZones = lib.mapAttrs (
            name: zone:
            let
              normalized = normalizeZone name zone;
              hasAllowUpdate = builtins.match ".*allow-update.*" (zone.extraConfig or "") != null;
            in
            if zone.master && hasAllowUpdate && builtins.isString zone.file then
              {
                storePath = pkgs.writeText "${name}.zone" zone.file;
                writable = "/var/lib/bind/zones/${name}.zone";
              }
            else
              null
          ) allZones;

          dynamicZonesFiltered = lib.filterAttrs (n: v: v != null) dynamicZones;
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

    # Create zone directory for slave zones and dynamic master zones
    systemd.tmpfiles.rules = [
      "d /var/lib/bind/zones 0755 named named -"
    ];

    # For primary server, copy zones with allow-update to writable location
    systemd.services.bind.preStart =
      let
        allZones = import ./zones { dns = inputs.dns; };
        dynamicZones = lib.mapAttrs (
          name: zone:
          let
            hasAllowUpdate = builtins.match ".*allow-update.*" (zone.extraConfig or "") != null;
          in
          if zone.master && hasAllowUpdate && builtins.isString zone.file then
            {
              storePath = pkgs.writeText "${name}.zone" zone.file;
              writable = "/var/lib/bind/zones/${name}.zone";
            }
          else
            null
        ) allZones;
        dynamicZonesFiltered = lib.filterAttrs (n: v: v != null) dynamicZones;
        copyCommands = lib.mapAttrsToList (
          name: info: "cp -f ${info.storePath} ${info.writable} && chown named:named ${info.writable}"
        ) dynamicZonesFiltered;
      in
      lib.mkIf (bindCfg.mode == "primary") (lib.concatStringsSep "\n" copyCommands);
  };
}
