{ pkgs, ... }:
let
  # suricata-update ships inside pkgs.suricata. It fetches ET Open by default,
  # verifies the published MD5 sidecar, merges category files into
  # suricata.rules, and refreshes classification.config — matching the layout
  # our suricata.yaml already expects.
  updateScript = pkgs.writeShellScript "suricata-update-rules" ''
    set -euo pipefail
    ${pkgs.suricata}/bin/suricata-update \
      --data-dir /var/lib/suricata \
      --suricata-conf /etc/suricata/suricata.yaml \
      --no-reload

    # Live-reload running suricata without restarting
    if ${pkgs.systemd}/bin/systemctl is-active --quiet suricata.service; then
      ${pkgs.systemd}/bin/systemctl kill --signal=SIGUSR2 suricata.service
    fi
  '';
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
    "d /var/lib/suricata        0750 suricata suricata -"
    "d /var/lib/suricata/rules  0750 suricata suricata -"
    "d /var/lib/suricata/update 0750 suricata suricata -"
    "d /var/log/suricata        0750 suricata suricata -"
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
  # ET Open rule updater (suricata-update)
  # -------------------------------------------------------------------------
  systemd.services.suricata-update-rules = {
    description = "Suricata rule updater (suricata-update, verifies MD5 sidecar)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = toString updateScript;
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

    loki.process "suricata_alerts" {
      forward_to = [loki.write.default.receiver]

      // Drop all non-alert event types (flow, dns, http, stats, tls, etc.)
      stage.match {
        selector            = "{job=\"suricata\"} != \"\\\"event_type\\\":\\\"alert\\\"\""
        action              = "drop"
        drop_counter_reason = "non_alert"
      }

      // Extract signature_severity from alert metadata as a stream label so
      // queries can use {sig_severity="Major"} as a fast indexed filter.
      stage.json {
        expressions = { sig_severity = "alert.metadata.signature_severity.0" }
      }

      stage.labels {
        values = { sig_severity = "" }
      }
    }

    loki.source.file "suricata_alerts" {
      targets    = local.file_match.suricata_alerts.targets
      forward_to = [loki.process.suricata_alerts.receiver]
    }
  '';
}
