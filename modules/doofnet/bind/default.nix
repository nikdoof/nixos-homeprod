{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (import ../const.nix) allNetworks;

  cfg = config.doofnet.bind;
  # Import all zones from the zones directory
  zones = import ./zones { inherit (inputs) dns; };

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

  publicSecondaryServers = [
    "52.19.64.4" # ns-03 (eu-west-1)
    "16.60.149.205" # ns-04 (eu-west-2)
  ];

  # Directory for mutable zone files
  zoneDir = "/var/lib/bind/zones";

  # Helper functions
  # A zone is dynamic if it accepts updates via either allow-update or update-policy;
  # both require a writable (non-store) zone file so BIND can maintain a journal.
  hasDynamicUpdates =
    zone:
    let
      extra = zone.value.extraConfig or "";
    in
    builtins.match ".*allow-update.*" extra != null || builtins.match ".*update-policy.*" extra != null;
  isPublicZone =
    zone:
    builtins.any (ns: builtins.match ".*ns-0[34]\\.doofnet\\.uk\\..*" ns != null) (
      zone.value.zoneData.NS or [ ]
    );
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
    slaves = secondaryServers ++ lib.optionals (isPublicZone zone) publicSecondaryServers;
    extraConfig = zone.value.extraConfig or "";
  };

  mkSecondaryZone = zone: {
    master = false;
    inherit (cfg) masters;
    file = "zones/${zone.name}";
  };

  # Active zone list — public secondaries only serve publicly-delegated zones
  activeZones = if cfg.publicOnly then builtins.filter isPublicZone zoneList else zoneList;

  # Filtered zone lists
  dynamicZones = builtins.filter hasDynamicUpdates activeZones;

  # Tmpfiles configuration for dynamic zones
  mkDynamicZoneFiles =
    zone:
    let
      zoneFile = writeZoneFile zone;
      serial = getZoneSerial zone;
    in
    {
      "${zoneDir}/${zone.name}.nix-serial" = {
        "f" = {
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
      if [ -f "${zonePath}" ]; then
        STORED_SERIAL=$(cat "${serialPath}" 2>/dev/null || echo "0")
        NIX_SERIAL="${toString serial}"

        if [ "$STORED_SERIAL" != "$NIX_SERIAL" ]; then
          echo "Zone ${zone.name}: Updating (serial $STORED_SERIAL -> $NIX_SERIAL)"
          if systemctl is-active --quiet bind.service; then
            rndc freeze ${zone.name}
            cp -f "${zonePath}" "${zonePath}.backup-$(date +%Y%m%d-%H%M%S)"
            TMPWORK=$(mktemp -d)
            # Normalise both zone files to fully-qualified one-record-per-line format
            named-compilezone -f text -F text -o "$TMPWORK/frozen.zone" "${zone.name}" "${zonePath}" 2>/dev/null
            named-compilezone -f text -F text -o "$TMPWORK/nix.zone"    "${zone.name}" "${zoneFilePath}" 2>/dev/null
            # Extract records whose owner name is absent from the Nix zone (dynamic DHCP entries)
            awk 'NR==FNR { names[$1]=1; next } !($1 in names) { print }' \
              "$TMPWORK/nix.zone" "$TMPWORK/frozen.zone" > "$TMPWORK/dynamic.zone"
            # Write Nix static records + preserved dynamic records
            cat "${zoneFilePath}" "$TMPWORK/dynamic.zone" > "${zonePath}"
            rm -rf "$TMPWORK"
            rndc thaw ${zone.name}
          else
            cp -f "${zonePath}" "${zonePath}.backup-$(date +%Y%m%d-%H%M%S)"
            cp -f "${zoneFilePath}" "${zonePath}"
            rm -f "${zonePath}.jnl"
          fi
          echo "$NIX_SERIAL" > "${serialPath}"
          echo "Zone ${zone.name}: Update complete"
        fi
      fi

      # Remove backups older than 7 days for this zone
      find "${zoneDir}" -maxdepth 1 -name "${zone.name}.zone.backup-*" -mtime +7 -delete
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

    masters = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = primaryServers;
      description = "Primary server IPs to transfer zones from. Override for external secondaries that reach the primary via NAT.";
    };

    publicOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Only serve publicly-delegated zones (those with ns-03/ns-04 in NS records). For public-facing secondaries.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Firewall
    networking.firewall = {
      allowedTCPPorts = [ 53 ] ++ lib.optionals (cfg.mode == "primary") [ 853 ];
      allowedUDPPorts = [ 53 ];
    };

    environment.etc."alloy/conf.d/02-bind.alloy".text = ''
      prometheus.scrape "bind" {
        targets    = [{"__address__" = "localhost:9119"}]
        forward_to = [prometheus.remote_write.default.receiver]
        job_name   = "bind"
      }
    '';

    # Zone directory and files
    systemd.tmpfiles.settings."bind-zones" =
      let
        baseDir = {
          ${zoneDir}.d = {
            user = "named";
            group = "named";
            mode = "0750";
          };
          "/var/log/named".d = {
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
      after = [ "systemd-tmpfiles-setup.service" ];
      path = [
        pkgs.bind
        pkgs.gawk
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "named";
        Group = "named";
      };
      script = lib.concatMapStringsSep "\n" mkZoneUpdateScript dynamicZones;
    };

    age.secrets = {
      doofnetZoneTransferKey = {
        file = ../../../secrets/doofnetZoneTransferKey.age;
        owner = "named";
      };
    }
    // lib.optionalAttrs (cfg.mode == "primary") {
      doofnetDnsUpdateKey = {
        file = ../../../secrets/doofnetDnsUpdateKey.age;
        owner = "named";
      };
      digitaloceanApiToken = {
        file = ../../../secrets/digitalOceanApiToken.age;
        owner = "acme";
      };
    };

    # Get a ACME cert for DNS (primary only — secondaries don't serve DoT)
    security.acme = lib.mkIf (cfg.mode == "primary") {
      certs = {
        "${config.networking.hostName}.${config.networking.domain}" = {
          dnsProvider = "digitalocean";
          dnsResolver = "1.1.1.1:53";
          environmentFile = pkgs.writeText "acme-env" ''
            DO_AUTH_TOKEN_FILE=${config.age.secrets.digitaloceanApiToken.path}
          '';
          group = "named";
          reloadServices = [
            "bind"
          ];
        };
      };
    };

    # Allow bind to write logs; ProtectSystem=strict requires explicit opt-in
    systemd.services.bind.serviceConfig.ReadWritePaths = [ "/var/log/named" ];

    # Alloy reads bind logs to ship to Loki
    systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "named" ];
    systemd.services.alloy.serviceConfig.ReadOnlyPaths = [ "/var/log/named" ];

    environment.etc."alloy/conf.d/03-bind-logs.alloy".text = ''
      local.file_match "bind_queries" {
        path_targets = [{"__path__" = "/var/log/named/queries.log", "job" = "bind", "host" = "${config.networking.hostName}", "logtype" = "queries"}]
        sync_period  = "5s"
      }

      local.file_match "bind_security" {
        path_targets = [{"__path__" = "/var/log/named/security.log", "job" = "bind", "host" = "${config.networking.hostName}", "logtype" = "security"}]
        sync_period  = "5s"
      }

      loki.source.file "bind_queries" {
        targets    = local.file_match.bind_queries.targets
        forward_to = [loki.process.bind_queries.receiver]
      }

      loki.source.file "bind_security" {
        targets    = local.file_match.bind_security.targets
        forward_to = [loki.process.bind_security.receiver]
      }

      loki.process "bind_queries" {
        stage.regex {
          expression = `^(?P<timestamp>\d{2}-\w{3}-\d{4} \d{2}:\d{2}:\d{2}\.\d{3}) client (?:@\S+ )?(?P<client_ip>[0-9a-f.:]+)#(?P<client_port>\d+) \([^)]+\): query: (?P<qname>\S+) (?P<qclass>\S+) (?P<qtype>\S+) (?P<flags>\S+)`
        }

        stage.timestamp {
          source   = "timestamp"
          format   = "02-Jan-2006 15:04:05.000"
          location = "Europe/London"
        }

        stage.labels {
          values = {
            qtype  = "qtype",
            qclass = "qclass",
          }
        }

        stage.structured_metadata {
          values = {
            client_ip   = "client_ip",
            client_port = "client_port",
            qname       = "qname",
            flags       = "flags",
          }
        }

        forward_to = [loki.write.default.receiver]
      }

      loki.process "bind_security" {
        stage.regex {
          expression = `^(?P<timestamp>\d{2}-\w{3}-\d{4} \d{2}:\d{2}:\d{2}\.\d{3}) (?P<category>\w[\w-]+): (?P<severity>\w+):`
        }

        stage.timestamp {
          source   = "timestamp"
          format   = "02-Jan-2006 15:04:05.000"
          location = "Europe/London"
        }

        stage.labels {
          values = {
            category = "category",
            severity = "severity",
          }
        }

        stage.structured_metadata {
          values = {
            client_ip   = "client_ip",
            client_port = "client_port",
          }
        }

        forward_to = [loki.write.default.receiver]
      }
    '';

    # BIND configuration
    services.bind = {
      enable = true;
      directory = "/var/lib/bind";
      forwarders = [ ];

      cacheNetworks = [
        "127.0.0.0/8"
        "::1"
      ]
      ++ allNetworks;

      zones = lib.listToAttrs (
        map (zone: {
          inherit (zone) name;
          value = if cfg.mode == "primary" then mkPrimaryZone zone else mkSecondaryZone zone;
        }) activeZones
      );

      extraOptions = ''
        version "none";
        hostname none;
        server-id none;

        // Zone transfer default-deny; per-zone allow-transfer overrides this
        allow-transfer { none; };

        dnssec-validation auto;
        qname-minimization relaxed;
        minimal-responses yes;

        // Cache limits
        max-cache-size 256m;
        max-cache-ttl 86400;
        max-ncache-ttl 3600;

        // Prefetch cache entries before they expire to avoid latency spikes
        prefetch 2 9;

        // Serve stale cache entries for up to 30s while refreshing, avoiding
        // SERVFAIL during brief upstream outages
        stale-answer-enable yes;
        stale-cache-enable yes;
        stale-answer-ttl 30;

        rate-limit {
          responses-per-second 10;
          window 5;
          exempt-clients {
            ${lib.concatMapStrings (n: "${n}; ") allNetworks}
          };
        };
        ${lib.optionalString (cfg.mode == "primary") ''
          listen-on port 853 tls local-tls { any; };
          listen-on-v6 port 853 tls local-tls { any; };
        ''}

        ${lib.optionalString (!cfg.publicOnly) ''
          // RPZ
          response-policy { zone "rpz"; } break-dnssec yes;
        ''}
      '';

      extraConfig = ''
        // Stats channel for prometheus-bind-exporter
        statistics-channels {
          inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
        };

        // Zone transfer TSIG key
        include "${config.age.secrets.doofnetZoneTransferKey.path}";

        ${lib.optionalString (cfg.mode == "primary") ''
          // Authenticate zone transfers to/from public secondaries with TSIG
          ${lib.concatMapStrings (ip: ''
            server ${ip} { keys { doofnet-zone-transfer; }; };
          '') publicSecondaryServers}

          // DHCP update key
          include "${config.age.secrets.doofnetDnsUpdateKey.path}";
          acl "doofnet-dhcp-updates" {
            key doofnet-dhcp-updates;
          };
        ''}

        ${lib.optionalString (cfg.mode == "secondary") ''
          // Authenticate zone transfers to/from primary with TSIG
          ${lib.concatMapStrings (ip: ''
            server ${ip} { keys { doofnet-zone-transfer; }; };
          '') cfg.masters}
        ''}

        ${lib.optionalString (cfg.mode == "primary") ''
          // DNS-over-TLS certificate
          tls local-tls {
            cert-file "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/fullchain.pem";
            key-file "/var/lib/acme/${config.networking.hostName}.${config.networking.domain}/key.pem";
          };
        ''}

        logging {
          // Security-relevant events: DNSSEC failures, TSIG errors, zone transfers
          channel security_file {
            file "/var/log/named/security.log" versions 3 size 20m;
            print-time yes;
            print-severity yes;
            print-category yes;
            severity dynamic;
          };

          // query log
          channel queries_file {
            file "/var/log/named/queries.log" versions 5 size 100m;
            print-time yes;
            severity info;
          };

          channel null_channel { null; };

          category default      { security_file; };
          category security     { security_file; };
          category dnssec       { security_file; };
          category query-errors { security_file; };
          category xfer-in      { security_file; };
          category xfer-out     { security_file; };
          category notify       { security_file; };
          category queries      { queries_file;  };

          // Suppress noisy low-signal categories
          category lame-servers  { null_channel; };
          category edns-disabled { null_channel; };
          category rpz           { null_channel; };
        };
      '';
    };

    # Monitoring
    services.prometheus.exporters.bind = {
      enable = true;
      openFirewall = false;
      listenAddress = "127.0.0.1";
    };

  };
}
