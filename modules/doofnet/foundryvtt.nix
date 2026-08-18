{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.doofnet.foundryvtt;
in
{
  options.doofnet.foundryvtt = {
    enable = lib.mkEnableOption "Foundry Virtual Tabletop server";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.foundryvtt;
      defaultText = lib.literalExpression "pkgs.foundryvtt";
      description = "FoundryVTT package (the Node.js application from foundryvtt.com).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 30000;
      description = "TCP port for the FoundryVTT HTTP server.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/persist/foundrydata";
      description = "Persistent data directory for FoundryVTT (worlds, config, modules).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the FoundryVTT port in the firewall.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    users.users.foundryvtt = {
      isSystemUser = true;
      group = "foundryvtt";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.foundryvtt = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 foundryvtt foundryvtt -"
    ];

    systemd.services.foundryvtt = {
      description = "Foundry Virtual Tabletop";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "foundryvtt";
        Group = "foundryvtt";
        WorkingDirectory = cfg.package;
        ExecStart = "${pkgs.nodejs}/bin/node main.js --dataPath=${cfg.dataDir} --port=${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = "5s";
        # /persist is already a persistent virtiofs mount in the microvm.
        # StateDirectory intentionally omitted; tmpfiles rules create the dir.
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
