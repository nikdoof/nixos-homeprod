{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.jrouter;

  # Serialise the settings attrset to YAML using nixpkgs' built-in generator.
  configFile = pkgs.writeTextFile {
    name = "jrouter.yaml";
    text = lib.generators.toYAML { } cfg.settings;
  };

  # Sub-module type for a single EtherTalk port entry.
  etherTalkType = lib.types.submodule {
    options = {
      device = lib.mkOption {
        type = lib.types.str;
        description = "Name of the Ethernet device (e.g. eth0, enp2s0).";
        example = "eth0";
      };

      ethernet_addr = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Override the hardware address used by jrouter. Useful when sharing an
          interface with another AppleTalk implementation such as netatalk.
        '';
        example = "08:00:07:fe:dc:ba";
      };

      zone_name = lib.mkOption {
        type = lib.types.str;
        description = "Default AppleTalk zone name for this network (max 32 chars, not empty or '*').";
        example = "The Twilight Zone";
      };

      extra_zones = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional zone names available in this network (max 32 chars each).";
        example = [
          "The Fright Zone"
          "GlobalGaming"
        ];
      };

      net_start = lib.mkOption {
        type = lib.types.int;
        description = "Start of the AppleTalk network number range (inclusive).";
        example = 100;
      };

      net_end = lib.mkOption {
        type = lib.types.int;
        description = "End of the AppleTalk network number range (inclusive).";
        example = 100;
      };
    };
  };

in
{
  options.services.jrouter = {
    enable = lib.mkEnableOption "jrouter, an AURP to EtherTalk router";

    package = lib.mkPackageOption pkgs "jrouter" { };

    settings = {
      listen_port = lib.mkOption {
        type = lib.types.port;
        default = 387;
        description = ''
          UDP port for the AURP server to listen on. Defaults to 387, the
          traditional AURP port. Change this only when running behind NAT.
        '';
      };

      local_ip = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          The publicly-routable IPv4 address used as this router's AURP Domain
          Identifier. Required when running behind NAT; otherwise jrouter picks
          the first global-unicast address on a local interface.
        '';
        example = "192.0.2.1";
      };

      monitoring_addr = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Address for the built-in HTTP monitoring server that exposes
          `/status` and `/metrics`. Leave null to disable.
        '';
        example = ":9459";
      };

      ethertalk = lib.mkOption {
        type = lib.types.listOf etherTalkType;
        default = [ ];
        description = "List of EtherTalk interface configurations.";
        example = lib.literalExpression ''
          [
            {
              device    = "eth0";
              zone_name = "My AppleTalk Zone";
              net_start = 100;
              net_end   = 100;
            }
          ]
        '';
      };

      open_peering = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          When true, jrouter accepts incoming AURP connections from peers not
          explicitly listed in `peers`. Recommended to keep enabled.
        '';
      };

      peers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "IP addresses or hostnames of AURP peers to proactively connect to.";
        example = [
          "192.0.2.2"
          "router.example.net"
        ];
      };

      peerlist_url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          URL of a plain-text file (one peer per line) to fetch on startup and
          merge with `peers`. Pull from the GlobalTalk peer list here.
        '';
        example = "http://example.com/peers.txt";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Make the jrouter binary available on the system path.
    environment.systemPackages = [ cfg.package ];

    systemd.services.jrouter = {
      description = "AURP to AppleTalk router";
      documentation = [ "https://gitea.drjosh.dev/josh/jrouter" ];

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/jrouter -config ${configFile}";
        Restart = "on-failure";
        RestartSec = "5s";

        # jrouter needs CAP_NET_RAW for pcap (EtherTalk) and
        # CAP_NET_BIND_SERVICE to bind UDP port 387.
        AmbientCapabilities = [
          "CAP_NET_RAW"
          "CAP_NET_BIND_SERVICE"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_RAW"
          "CAP_NET_BIND_SERVICE"
        ];

        # Run as an unprivileged dynamic user; capabilities above are
        # sufficient for everything jrouter needs.
        DynamicUser = true;

        # Hardening
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_PACKET"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
        ];
        UMask = "0077";
      };
    };
  };
}
