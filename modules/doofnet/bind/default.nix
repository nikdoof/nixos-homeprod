{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.doofnet.bind;

  # Import all zones from the zones directory
  # Each zone file returns { zoneData = <zone definition>; extraConfig = "..."; }
  zones = import ./zones { dns = inputs.dns; };

  # Extract zone name from attribute name
  # (filename without .nix extension becomes the zone name)
  zoneList = lib.mapAttrsToList (name: value: { inherit name value; }) zones;

  # Secondary server IPs for zone transfers
  secondaryServers = [
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];

  # Primary server IPs for zone transfers
  primaryServers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
  ];

  # Persistent directory for zone files (allows dynamic updates)
  zoneDir = "/var/lib/bind/zones";

  # Write zone data to a file in /nix/store (for templating)
  writeZoneTemplate =
    name: zoneData:
    pkgs.writeTextFile {
      name = "${name}.zone";
      text = inputs.dns.lib.toString name zoneData;
    };

  # Check if a zone has dynamic updates enabled
  hasDynamicUpdates =
    zone:
    let
      extraConfig = zone.value.extraConfig or "";
    in
    builtins.match ".*allow-update.*" extraConfig != null;

  # Generate zone configuration for primary mode
  primaryZoneConfig = zone: {
    master = true;
    # Use persistent directory for zones with dynamic updates, /nix/store for static zones
    file =
      if hasDynamicUpdates zone then
        "${zoneDir}/${zone.name}.zone"
      else
        writeZoneTemplate zone.name zone.value.zoneData;
    slaves = secondaryServers;
    extraConfig = zone.value.extraConfig or "";
  };

  # Generate zone configuration for secondary mode
  secondaryZoneConfig = zone: {
    master = false;
    masters = primaryServers;
    file = "secondary/${zone.name}";
  };

  # List of zones that need dynamic updates
  dynamicZones = builtins.filter hasDynamicUpdates zoneList;

  # Generate tmpfiles rules to copy zone templates only if they don't exist
  dynamicZoneTmpfiles = lib.listToAttrs (
    map (zone: {
      name = "${zoneDir}/${zone.name}.zone";
      value = {
        "C+" = {
          user = "named";
          group = "named";
          mode = "0640";
          argument = toString (writeZoneTemplate zone.name zone.value.zoneData);
        };
      };
    }) dynamicZones
  );

in
{
  options.doofnet.bind = {
    enable = lib.mkEnableOption "BIND DNS server";

    mode = lib.mkOption {
      type = lib.types.enum [
        "primary"
        "secondary"
      ];
      default = "primary";
      description = "Whether this server acts as a primary or secondary DNS server";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 53 ];
    networking.firewall.allowedUDPPorts = [ 53 ];

    # DHCP Update Key
    age.secrets.digitaloceanApiToken = {
      file = ../../../secrets/doofnetDnsUpdateKey.age;
      owner = "named";
    };

    # Create persistent zone directory for dynamic zones
    systemd.tmpfiles.settings."bind-zones" = lib.mkIf (cfg.mode == "primary") (
      {
        ${zoneDir} = {
          d = {
            user = "named";
            group = "named";
            mode = "0750";
          };
        };
      }
      // dynamicZoneTmpfiles
    );

    services.bind = {
      enable = true;

      # Use /var/lib/bind as working directory for persistence
      directory = "/var/lib/bind";

      # Don't forward queries
      forwarders = [ ];

      # Networks to cache queries for
      cacheNetworks = [
        "10.0.0.0/8"
        "2001:8b0:bd9::/48"
        "fddd:d00f:dab0::/48"
      ];

      # Configure zones based on mode
      zones = lib.listToAttrs (
        map (zone: {
          name = zone.name;
          value = if cfg.mode == "primary" then primaryZoneConfig zone else secondaryZoneConfig zone;
        }) zoneList
      );

      extraConfig = ''
        // Stats channel for prometheus-bind-exporter
        statistics-channels {
          inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
        };

        // HE.net DNS transfer
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
    };

    services.prometheus.exporters.bind = {
      enable = true;
      openFirewall = true;
    };
  };
}
