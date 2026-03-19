{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.dropbox-notify;

  dropbox-notify = pkgs.callPackage ../../packages/dropbox-notify { };
in
{
  options.services.dropbox-notify = {
    enable = lib.mkEnableOption "dropbox-notify, an inotify-based Mastodon poster for new files";

    watchDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory to watch for new user files.";
      example = "/persist/netatalk/shares/dropbox";
    };

    instanceUrl = lib.mkOption {
      type = lib.types.str;
      description = "Base URL of the Mastodon-compatible ActivityPub instance.";
      example = "https://social.doofnet.uk";
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to a file containing the Mastodon API access token (e.g. from agenix).";
      example = "/run/agenix/dropboxNotifyToken";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "DEBUG"
        "INFO"
        "WARNING"
        "ERROR"
      ];
      default = "INFO";
      description = "Logging verbosity for the dropbox-notify service.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.dropboxNotifyToken = {
      file = ../../secrets/dropboxNotifyToken.age;
      owner = "dropbox-notify";
      group = "dropbox-notify";
      mode = "0400";
    };

    users.users.dropbox-notify = {
      isSystemUser = true;
      group = "dropbox-notify";
      description = "dropbox-notify service user";
      # The netatalk dropbox share is writable by nobody and nikdoof.
      # We join the 'nobody' group so the service can read files dropped there
      # without needing any write access itself.
      extraGroups = [ "nobody" ];
    };

    users.groups.dropbox-notify = { };

    systemd.services.dropbox-notify = {
      description = "Watch the AFP dropbox share and toot on new uploads";
      documentation = [ "https://github.com/nikdoof/nixos-homeprod" ];

      after = [
        "network.target"
        "netatalk.service"
      ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          "${dropbox-notify}/bin/dropbox-notify"
          "--watch-dir ${cfg.watchDir}"
          "--instance-url ${cfg.instanceUrl}"
          "--token-file ${cfg.tokenFile}"
          "--log-level ${cfg.logLevel}"
        ];

        User = "dropbox-notify";
        Group = "dropbox-notify";

        Restart = "on-failure";
        RestartSec = "10s";

        # /persist is a virtiofs mount that lives outside the normal FHS tree,
        # so we cannot use ProtectSystem=strict (which makes / read-only and
        # would block access to /persist).  "full" protects /usr, /boot and
        # /etc while leaving other top-level mounts accessible.
        ProtectSystem = "full";
        ProtectHome = true;

        # Explicitly allow reads from the watch directory and the token.
        # ReadWritePaths is empty – the service never writes anything.
        ReadOnlyPaths = [
          cfg.watchDir
          cfg.tokenFile
        ];
        ReadWritePaths = [ ];

        # Hardening
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
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
