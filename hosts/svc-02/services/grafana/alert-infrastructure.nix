# Infrastructure alert group: WAN connectivity, NAS temperatures, WiFi,
# Hetzner storage, and monitoring stack health.
mkPromData: {
  orgId = 1;
  name = "Infrastructure";
  folder = "Alerts";
  interval = "1m";
  rules = [
    {
      uid = "infra-wan-latency-warning";
      title = "WAN High Latency (Warning)";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "WAN latency elevated";
        description = ''
          Ping to 81.187.81.187 has been above 50ms for more than 5 minutes.
          Current RTT: {{ printf "%.1f" $values.B.Value }}s. This may indicate
          congestion or line degradation on the A&A connection.
        '';
      };
      data = mkPromData {
        expr = ''max(ping_rtt_mean_seconds{target="81.187.81.187"})'';
        threshold = 0.05;
      };
    }

    {
      uid = "infra-wan-latency-critical";
      title = "WAN High Latency (Critical)";
      condition = "C";
      for = "2m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "WAN latency critical";
        description = ''
          Ping to 81.187.81.187 has been above 200ms for more than 2 minutes.
          Current RTT: {{ printf "%.1f" $values.B.Value }}s. The WAN connection
          is severely degraded or close to dropping.
        '';
      };
      data = mkPromData {
        expr = ''max(ping_rtt_mean_seconds{target="81.187.81.187"})'';
        threshold = 0.2;
      };
    }

    {
      uid = "infra-wan-jitter";
      title = "WAN High Jitter";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "WAN jitter elevated";
        description = ''
          Ping jitter to 81.187.81.187 has been above 20ms for more than 5 minutes.
          Current jitter: {{ printf "%.1f" $values.B.Value }}s. High jitter indicates
          an unstable line that will impact real-time traffic.
        '';
      };
      data = mkPromData {
        expr = ''max(ping_rtt_std_deviation_seconds{target="81.187.81.187"})'';
        threshold = 0.02;
      };
    }

    {
      uid = "infra-nas-disk-temp-warning";
      title = "NAS Disk Temperature (Warning)";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "NAS disk temperature elevated: {{ $labels.serial }}";
        description = ''
          Disk {{ $labels.serial }} on nas-03 has been above 40°C for more than
          5 minutes. Current temperature: {{ printf "%.0f" $values.B.Value }}°C.
          Check enclosure airflow and fan status.
        '';
      };
      data = mkPromData {
        expr = ''avg by(serial) (disk_temperature{exported_instance="nas-03"})'';
        threshold = 40;
      };
    }

    {
      uid = "infra-nas-disk-temp-critical";
      title = "NAS Disk Temperature (Critical)";
      condition = "C";
      for = "2m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "NAS disk temperature critical: {{ $labels.serial }}";
        description = ''
          Disk {{ $labels.serial }} on nas-03 has been above 50°C for more than
          2 minutes. Current temperature: {{ printf "%.0f" $values.B.Value }}°C.
          This is approaching the safe operating limit. Shut down and investigate
          cooling immediately.
        '';
      };
      data = mkPromData {
        expr = ''avg by(serial) (disk_temperature{exported_instance="nas-03"})'';
        threshold = 50;
      };
    }

    {
      uid = "infra-wifi-warning";
      title = "WiFi Performance Degraded (Warning)";
      condition = "C";
      for = "10m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "WiFi satisfaction low on {{ $labels.essid }}";
        description = ''
          Client satisfaction ratio on SSID {{ $labels.essid }} has been below
          70% for more than 10 minutes. Current value: {{ printf "%.2f" $values.B.Value }}.
          This may indicate RF interference, channel congestion, or AP issues.
        '';
      };
      data = mkPromData {
        expr = "avg by(essid) (unpoller_client_satisfaction_ratio)";
        threshold = 0.70;
        thresholdType = "lt";
      };
    }

    {
      uid = "infra-wifi-critical";
      title = "WiFi Performance Degraded (Critical)";
      condition = "C";
      for = "10m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "WiFi satisfaction critically low on {{ $labels.essid }}";
        description = ''
          Client satisfaction ratio on SSID {{ $labels.essid }} has been below
          50% for more than 10 minutes. Current value: {{ printf "%.2f" $values.B.Value }}.
          Clients on this SSID are experiencing severe connectivity issues.
        '';
      };
      data = mkPromData {
        expr = "avg by(essid) (unpoller_client_satisfaction_ratio)";
        threshold = 0.50;
        thresholdType = "lt";
      };
    }

    {
      uid = "infra-hetzner-storage-warning";
      title = "Hetzner Storage Usage High (Warning)";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Hetzner storage box above 85% capacity";
        description = ''
          Hetzner storage box usage has been above 85% for more than 5 minutes.
          Current usage: {{ printf "%.1f" $values.B.Value }} (ratio).
          Consider pruning old backups or expanding quota.
        '';
      };
      data = mkPromData {
        expr = "max(hcloud_storagebox_data_size / hcloud_storagebox_quota)";
        threshold = 0.85;
      };
    }

    {
      uid = "infra-hetzner-storage-critical";
      title = "Hetzner Storage Usage High (Critical)";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Hetzner storage box above 95% capacity";
        description = ''
          Hetzner storage box usage has exceeded 95% for more than 5 minutes.
          Current usage: {{ printf "%.1f" $values.B.Value }} (ratio).
          Backup jobs are at risk of failing. Prune old snapshots immediately.
        '';
      };
      data = mkPromData {
        expr = "max(hcloud_storagebox_data_size / hcloud_storagebox_quota)";
        threshold = 0.95;
      };
    }

    {
      uid = "infra-gw-ppp0-down";
      title = "Gateway WAN Interface Down";
      condition = "C";
      for = "2m";
      noDataState = "Alerting";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "ppp0 WAN interface is down on gw";
        description = ''
          The ppp0 PPPoE interface on gw has been absent or down for more than
          2 minutes. WAN connectivity is lost. Check the CityFibre ONT, vlan-wan,
          and pppd service status.
        '';
      };
      data = mkPromData {
        # node_network_up is always 0 for PPP (operstate=unknown is normal);
        # node_network_carrier reflects actual link state
        expr = ''min(node_network_carrier{instance="gw",device="ppp0"})'';
        threshold = 1;
        thresholdType = "lt";
      };
    }

    {
      uid = "infra-gw-dhcp4-pool";
      title = "Gateway DHCPv4 Pool Near Exhaustion";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "DHCPv4 pool above 85% utilisation on {{ $labels.subnet }}";
        description = ''
          Kea DHCPv4 pool on subnet {{ $labels.subnet }} has been above 85%
          utilised for more than 5 minutes.
          Current ratio: {{ printf "%.2f" $values.B.Value }}.
          Check for lease exhaustion or rogue clients.
        '';
      };
      data = mkPromData {
        expr = ''
          max by(subnet) (
            kea_dhcp4_allocated_addresses / kea_dhcp4_total_addresses
          )
        '';
        threshold = 0.85;
      };
    }

    {
      uid = "infra-gw-conntrack";
      title = "Gateway Conntrack Near Saturation";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "nf_conntrack table above 80% on gw";
        description = ''
          The netfilter conntrack table on gw has been above 80% full for more
          than 5 minutes.
          Current ratio: {{ printf "%.2f" $values.B.Value }}.
          At saturation new connections will be dropped. Consider raising
          nf_conntrack_max or investigating high-connection-count processes.
        '';
      };
      data = mkPromData {
        expr = ''
          max(
            node_nf_conntrack_entries{instance="gw:9100"}
            / node_nf_conntrack_entries_limit{instance="gw:9100"}
          )
        '';
        threshold = 0.80;
      };
    }

    {
      uid = "infra-gw-chrony-unsync";
      title = "Gateway NTP Not Synchronised";
      condition = "C";
      for = "10m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Chrony on gw is not synchronised to a time source";
        description = ''
          Chrony stratum on gw has been 16 or higher (unsynchronised) for more
          than 10 minutes. Current stratum: {{ printf "%.0f" $values.B.Value }}.
          Check upstream NTP server reachability and chrony service status.
        '';
      };
      data = mkPromData {
        expr = ''max(chrony_tracking_stratum{instance="gw:9123"})'';
        threshold = 15;
      };
    }

    {
      uid = "infra-prometheus-retention";
      title = "Prometheus Retention Low";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Prometheus TSDB retention unexpectedly low";
        description = ''
          Prometheus retention is below 30 days, which is unexpected given the
          configured 365-day retention policy. Current retention:
          {{ printf "%.0f" $values.B.Value }} days. This may indicate TSDB
          compaction issues, unexpected data loss, or the instance was recently
          reset.
        '';
      };
      data = mkPromData {
        expr = ''
          avg(
            (time() - (prometheus_tsdb_lowest_timestamp / 1000)) / 86400
          )
        '';
        threshold = 30;
        thresholdType = "lt";
      };
    }
  ];
}
