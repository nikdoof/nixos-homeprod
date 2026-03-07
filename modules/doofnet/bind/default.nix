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
  zones = import ./zones { dns = inputs.dns; };

  # Convert zones attrset to list for easier processing
  zoneList = lib.mapAttrsToList (name: value: { inherit name value; }) zones;

  # Server configuration
  secondaryServers = [
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];

  primaryServers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
  ];

  heNetServers = [
    "216.218.133.2"
    "2001:470:600::2"
  ];

  # Directory for mutable zone files
  zoneDir = "/var/lib/bind/zones";

  # Helper functions
  hasDynamicUpdates = zone: builtins.match ".*allow-update.*" (zone.value.extraConfig or "") != null;
  hasHeNetNameservers =
    zone:
    builtins.any (ns: builtins.match ".*he\\.net\\..*" ns != null) (zone.value.zoneData.NS or [ ]);
  getZoneSerial = zone: zone.value.zoneData.SOA.serial or 0;

  writeZoneFile =
    zone:
    pkgs.writeTextFile {
      name = "${zone.name}.zone";
      text = inputs.dns.lib.toString zone.name zone.value.zoneData;
    };

  # Zone configuration builders
  mkPrimaryZone = zone: {
    master = true;
    file = if hasDynamicUpdates zone then "${zoneDir}/${zone.name}.zone" else writeZoneFile zone;
    slaves = secondaryServers ++ lib.optionals (hasHeNetNameservers zone) heNetServers;
    extraConfig = zone.value.extraConfig or "";
  };

  mkSecondaryZone = zone: {
    master = false;
    masters = primaryServers;
    file = "zones/${zone.name}";
  };

  # Filtered zone lists
  dynamicZones = builtins.filter hasDynamicUpdates zoneList;

  # Tmpfiles configuration for dynamic zones
  mkDynamicZoneFiles =
    zone:
    let
      zoneFile = writeZoneFile zone;
      serial = getZoneSerial zone;
    in
    {
      "${zoneDir}/${zone.name}.nix-serial" = {
        "f+" = {
          user = "named";
          group = "named";
          mode = "0640";
          argument = toString serial;
        };
      };
      "${zoneDir}/${zone.name}.zone" = {
        "C+" = {
          user = "named";
          group = "named";
          mode = "0640";
          argument = toString zoneFile;
        };
      };
    };

  # Update script for dynamic zones
  mkZoneUpdateScript =
    zone:
    let
      zoneFile = writeZoneFile zone;
      zoneFilePath = builtins.unsafeDiscardStringContext (toString zoneFile);
      serial = getZoneSerial zone;
      zonePath = "${zoneDir}/${zone.name}.zone";
      serialPath = "${zoneDir}/${zone.name}.nix-serial";
    in
    ''
      if [ -f "${zonePath}" ] && [ -f "${serialPath}" ]; then
        STORED_SERIAL=$(cat "${serialPath}" 2>/dev/null || echo "0")
        NIX_SERIAL="${toString serial}"

        if [ "$STORED_SERIAL" != "$NIX_SERIAL" ]; then
          echo "Zone ${zone.name}: Updating (serial $STORED_SERIAL -> $NIX_SERIAL)"
          cp -f "${zonePath}" "${zonePath}.backup-$(date +%Y%m%d-%H%M%S)"
          cp -f "${zoneFilePath}" "${zonePath}"
          echo "$NIX_SERIAL" > "${serialPath}"
          rm -f "${zonePath}.jnl"
          echo "Zone ${zone.name}: Update complete"
        fi
      fi
    '';

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
      description = "Server mode: primary (master) or secondary (slave)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Firewall
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    # Secrets
    age.secrets.doofnetDnsUpdateKey = {
      file = ../../../secrets/doofnetDnsUpdateKey.age;
      owner = "named";
    };

    # Zone directory and files
    systemd.tmpfiles.settings."bind-zones" =
      let
        baseDir = {
          ${zoneDir}.d = {
            user = "named";
            group = "named";
            mode = "0750";
          };
        };
        dynamicFiles = lib.foldl' (acc: zone: acc // mkDynamicZoneFiles zone) { } dynamicZones;
      in
      if cfg.mode == "primary" then baseDir // dynamicFiles else baseDir;

    # Zone update service (primary only)
    systemd.services.bind-update-zones = lib.mkIf (cfg.mode == "primary" && dynamicZones != [ ]) {
      description = "Update BIND zone files when Nix configuration changes";
      wantedBy = [ "bind.service" ];
      before = [ "bind.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "named";
        Group = "named";
      };
      script = lib.concatMapStringsSep "\n" mkZoneUpdateScript dynamicZones;
    };

    # BIND configuration
    services.bind = {
      enable = true;
      directory = "/var/lib/bind";
      forwarders = [ ];

      cacheNetworks = [
        "10.0.0.0/8"
        "2001:8b0:bd9::/48"
        "fddd:d00f:dab0::/48"
      ];

      zones = lib.listToAttrs (
        map (zone: {
          name = zone.name;
          value = if cfg.mode == "primary" then mkPrimaryZone zone else mkSecondaryZone zone;
        }) zoneList
      );

      extraOptions = ''
        // RPZ
        response-policy { zone "rpz"; };
      '';

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
        include "${config.age.secrets.doofnetDnsUpdateKey.path}";
        acl "doofnet-dhcp-updates" {
          key doofnet-dhcp-updates;
        };
      '';
    };

    # Monitoring
    services.prometheus.exporters.bind = {
      enable = true;
      openFirewall = false;
    };

    networking.firewall = {
      extraCommands = ''
        # Allow bind-exporter metrics port from Prometheus system
        iptables -A nixos-fw -p tcp -m tcp --dport ${toString config.services.prometheus.exporters.bind.port} -s 10.101.0.0/16 -j nixos-fw-accept -m comment --comment "bind-exporter"
        ip6tables -A nixos-fw -p tcp -m tcp --dport ${toString config.services.prometheus.exporters.bind.port} -s fddd:d00f:dab0:101::/64 -j nixos-fw-accept -m comment --comment "bind-exporter"
        ip6tables -A nixos-fw -p tcp -m tcp --dport ${toString config.services.prometheus.exporters.bind.port} -s 2001:8b0:bd9:101::21/64 -j nixos-fw-accept -m comment --comment "bind-exporter"
      '';
    };
  };
}
