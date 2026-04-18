{ pkgs, ... }:
let
  rulesUrl = "https://rules.emergingthreats.net/open/suricata-${pkgs.suricata.version}/emerging.rules.tar.gz";

  updateScript = pkgs.writeShellApplication {
    name = "suricata-update-rules";
    runtimeInputs = with pkgs; [
      curl
      gnutar
      gzip
    ];
    text = ''
      set -euo pipefail

      RULES_DIR=/var/lib/suricata/rules
      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT

      echo "Fetching ET Open rules for Suricata ${pkgs.suricata.version}..."
      curl -sL "${rulesUrl}" | tar -xz -C "$TMP"

      # Merge all category rule files into a single file (mirrors suricata-update output)
      cat "$TMP"/rules/emerging-*.rules > "$RULES_DIR/suricata.rules"

      # Pull in the classification config shipped with the ruleset
      cp "$TMP/rules/classification.config" "$RULES_DIR/"

      COUNT=$(wc -l < "$RULES_DIR/suricata.rules")
      echo "Rules updated: $COUNT lines."

      # Signal Suricata to live-reload rules without restarting
      if systemctl is-active --quiet suricata.service; then
        echo "Sending SIGUSR2 to reload rules..."
        systemctl kill --signal=SIGUSR2 suricata.service
      fi
    '';
  };
in
{
  users.users.suricata = {
    isSystemUser = true;
    group = "suricata";
    description = "Suricata IDS";
  };
  users.groups.suricata = { };

  environment.etc."suricata/suricata.yaml".source = ./files/suricata.yaml;
  environment.etc."suricata/reference.config".source =
    "${pkgs.suricata}/etc/suricata/reference.config";
  environment.etc."suricata/threshold.config".source =
    "${pkgs.suricata}/etc/suricata/threshold.config";

  systemd.tmpfiles.rules = [
    "d /var/lib/suricata       0750 suricata suricata -"
    "d /var/lib/suricata/rules 0750 suricata suricata -"
    "d /var/log/suricata       0750 suricata suricata -"
  ];

  # -------------------------------------------------------------------------
  # Main IDS service
  # -------------------------------------------------------------------------
  systemd.services.suricata = {
    description = "Suricata IDS — vlan-hosted (passive)";
    after = [
      "suricata-update-rules.service"
      "network.target"
    ];
    wants = [ "suricata-update-rules.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.ConditionPathExists = "/var/lib/suricata/rules/suricata.rules";

    serviceConfig = {
      ExecStart = "${pkgs.suricata}/bin/suricata -c /etc/suricata/suricata.yaml --af-packet";
      ExecReload = "${pkgs.coreutils}/bin/kill -USR2 $MAINPID";
      Restart = "on-failure";
      RestartSec = "10s";

      User = "suricata";
      Group = "suricata";

      AmbientCapabilities = [
        "CAP_NET_RAW"
        "CAP_NET_ADMIN"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_RAW"
        "CAP_NET_ADMIN"
      ];

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        "/var/log/suricata"
        "/var/lib/suricata"
      ];
    };
  };

  # -------------------------------------------------------------------------
  # ET Open rule updater
  # -------------------------------------------------------------------------
  systemd.services.suricata-update-rules = {
    description = "Suricata ET Open rules updater";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${updateScript}/bin/suricata-update-rules";
      User = "suricata";
      Group = "suricata";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/suricata" ];
    };
  };

  # Run at boot (5 min delay for network) then daily thereafter
  systemd.timers.suricata-update-rules = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # Allow Alloy (DynamicUser) to read Suricata logs
  systemd.services.alloy.serviceConfig.SupplementaryGroups = [ "suricata" ];
  systemd.services.alloy.serviceConfig.ReadOnlyPaths = [ "/var/log/suricata" ];

  # -------------------------------------------------------------------------
  # Alloy: tail eve.json → Loki
  # -------------------------------------------------------------------------
  environment.etc."alloy/conf.d/03-suricata.alloy".text = ''
    local.file_match "suricata_alerts" {
      path_targets = [{"__path__" = "/var/log/suricata/eve.json", "job" = "suricata", "host" = "gw"}]
      sync_period  = "5s"
    }

    loki.source.file "suricata_alerts" {
      targets    = local.file_match.suricata_alerts.targets
      forward_to = [loki.write.default.receiver]
    }
  '';
}
