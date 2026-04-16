{ pkgs, ... }:
let
  rulesUrl = "https://rules.emergingthreats.net/open/snort-3.0/emerging.rules.tar.gz";

  updateScript = pkgs.writeShellApplication {
    name = "snort-update-rules";
    runtimeInputs = with pkgs; [
      curl
      gnutar
      gzip
    ];
    text = ''
      set -euo pipefail

      RULES_DIR=/var/lib/snort/rules
      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT

      echo "Fetching ET Open rules for Snort 3..."
      curl -sL "${rulesUrl}" | tar -xz -C "$TMP"

      # Atomically replace existing rules
      find "$RULES_DIR" -name '*.rules' -delete
      mv "$TMP"/rules/*.rules "$RULES_DIR"/

      # Generate master include file consumed by snort.lua
      true > "$RULES_DIR/snort.rules"
      for f in "$RULES_DIR"/emerging-*.rules; do
        echo "include $f"
      done >> "$RULES_DIR/snort.rules"

      COUNT=$(wc -l < "$RULES_DIR/snort.rules")
      echo "Rules updated: $COUNT category files."

      # Signal Snort to reload without restarting
      if systemctl is-active --quiet snort.service; then
        echo "Sending SIGHUP to reload rules..."
        systemctl kill --signal=HUP snort.service
      fi
    '';
  };
in
{
  users.users.snort = {
    isSystemUser = true;
    group = "snort";
    description = "Snort IDS";
  };
  users.groups.snort = { };

  # Snort 3 Lua config — edit files/snort.lua to tune variables and suppress list
  environment.etc."snort/snort.lua".source = ./files/snort.lua;

  # Runtime directories owned by the snort user
  systemd.tmpfiles.rules = [
    "d /var/lib/snort       0750 snort snort -"
    "d /var/lib/snort/rules 0750 snort snort -"
    "d /var/log/snort       0750 snort snort -"
  ];

  # -------------------------------------------------------------------------
  # Main IDS service
  # -------------------------------------------------------------------------
  systemd.services.snort = {
    description = "Snort 3 IDS — vlan-hosted (passive)";
    # Ordered after the rule updater so rules exist on first boot;
    # no direct network dependency — snort passively reads an interface
    after = [ "snort-update-rules.service" ];
    wants = [ "snort-update-rules.service" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.ConditionPathExists = "/var/lib/snort/rules/snort.rules";

    serviceConfig = {
      ExecStart = "${pkgs.snort}/bin/snort --daq-dir ${pkgs.libdaq}/lib/daq --daq afpacket --daq-mode passive -i vlan-hosted -c /etc/snort/snort.lua -l /var/log/snort";
      Restart = "on-failure";
      RestartSec = "10s";

      User = "snort";
      Group = "snort";

      # Promiscuous AF_PACKET requires these two capabilities; nothing else
      AmbientCapabilities = [
        "CAP_NET_RAW"
        "CAP_NET_ADMIN"
      ];
      CapabilityBoundingSet = [
        "CAP_NET_RAW"
        "CAP_NET_ADMIN"
      ];

      # Hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [
        "/var/log/snort"
        "/var/lib/snort"
      ];
    };
  };

  # -------------------------------------------------------------------------
  # ET Open rule updater
  # -------------------------------------------------------------------------
  systemd.services.snort-update-rules = {
    description = "Snort ET Open rules updater";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${updateScript}/bin/snort-update-rules";
      User = "snort";
      Group = "snort";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/snort" ];
    };
  };

  # Run at boot (5 min delay for network) then daily thereafter
  systemd.timers.snort-update-rules = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # -------------------------------------------------------------------------
  # Alloy: tail alert_json.txt → Loki
  # -------------------------------------------------------------------------
  environment.etc."alloy/conf.d/03-snort.alloy".text = ''
    local.file_match "snort_alerts" {
      path_targets = [{"__path__" = "/var/log/snort/alert_json.txt", "job" = "snort", "host" = "gw"}]
      sync_period  = "5s"
    }

    loki.source.file "snort_alerts" {
      targets    = local.file_match.snort_alerts.targets
      forward_to = [loki.write.default.receiver]
    }
  '';
}
