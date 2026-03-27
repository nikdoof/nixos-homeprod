{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.doofnet.opendmarc;

  toConfValue = v: if lib.isBool v then (if v then "true" else "false") else toString v;

  # Module manages Socket, PidFile, Syslog, and UMask; everything else comes from settings.
  resolvedSettings = {
    Socket = cfg.socket;
    PidFile = "/run/opendmarc/opendmarc.pid";
    Syslog = true;
    UMask = "0117";
  }
  // cfg.settings;

  configFile = pkgs.writeText "opendmarc.conf" (
    lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k} ${toConfValue v}") resolvedSettings)
    + "\n"
  );
in
{
  options.doofnet.opendmarc = {
    enable = lib.mkEnableOption "OpenDMARC milter";

    socket = lib.mkOption {
      type = lib.types.str;
      default = "local:/run/opendmarc/opendmarc.sock";
      description = "Milter socket specification passed to OpenDMARC (e.g. local:/path or inet:port@host).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "opendmarc";
      description = "User account under which OpenDMARC runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "opendmarc";
      description = "Group under which OpenDMARC runs.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.oneOf [
          lib.types.str
          lib.types.bool
          lib.types.int
        ]
      );
      default = { };
      description = ''
        Settings written verbatim to opendmarc.conf.
        Socket, PidFile, Syslog, and UMask are managed by this module.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "opendmarc") {
      opendmarc = {
        isSystemUser = true;
        inherit (cfg) group;
        description = "OpenDMARC daemon user";
      };
    };

    users.groups = lib.mkIf (cfg.group == "opendmarc") {
      opendmarc = { };
    };

    systemd.services.opendmarc = {
      description = "OpenDMARC milter";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        Type = "forking";
        User = cfg.user;
        Group = cfg.group;
        PIDFile = "/run/opendmarc/opendmarc.pid";
        ExecStart = "${pkgs.opendmarc}/bin/opendmarc -c ${configFile}";
        RuntimeDirectory = "opendmarc";
        RuntimeDirectoryMode = "0750";
        Restart = "on-failure";
      };
    };
  };
}
