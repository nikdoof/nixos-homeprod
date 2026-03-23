# Hardware alert group: CPU, memory, swap, disk health, node availability.
mkPromData: {
  orgId = 1;
  name = "Hardware";
  folder = "Alerts";
  interval = "1m";
  rules = [
    {
      uid = "hw-high-cpu";
      title = "High CPU Usage";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "High CPU usage on {{ $labels.host }}";
        description = ''
          CPU usage on {{ $labels.host }} has been above 80% for more than 5 minutes.
          Current usage: {{ printf "%.1f" $values.B.Value }}%.
          This is averaged across all cores.
        '';
      };
      data = mkPromData {
        expr = ''
          100 - (
            avg by (host) (
              rate(node_cpu_seconds_total{mode="idle",job="node_exporter"}[5m])
            ) * 100
          )
        '';
        threshold = 80;
      };
    }

    {
      uid = "hw-high-memory";
      title = "High Memory Usage";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "High memory usage on {{ $labels.host }}";
        description = ''
          Memory usage on {{ $labels.host }} has been above 90% for more than 5 minutes.
          Current usage: {{ printf "%.1f" $values.B.Value }}%.
          This uses MemAvailable and only fires under genuine memory pressure,
          not due to reclaimable cache.
        '';
      };
      data = mkPromData {
        expr = ''
          (
            1 - (
              node_memory_MemAvailable_bytes{job="node_exporter"}
              / node_memory_MemTotal_bytes{job="node_exporter"}
            )
          ) * 100
        '';
        threshold = 90;
      };
    }

    {
      uid = "hw-heavy-swap";
      title = "Heavy Swap Activity";
      condition = "C";
      for = "2m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Heavy swap activity on {{ $labels.host }}";
        description = ''
          {{ $labels.host }} is paging at {{ printf "%.0f" $values.B.Value }} pages/sec,
          indicating significant memory pressure. Sustained swap activity can severely
          degrade system performance. Consider investigating high-memory processes.
        '';
      };
      data = mkPromData {
        expr = ''
          rate(node_vmstat_pswpin{job="node_exporter"}[5m])
          + rate(node_vmstat_pswpout{job="node_exporter"}[5m])
        '';
        threshold = 100;
      };
    }

    {
      uid = "hw-disk-smart-fail";
      title = "Disk SMART Failure";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "SMART failure on {{ $labels.host }}: {{ $labels.device }}";
        description = ''
          SMART overall health check has returned FAILED for device {{ $labels.device }}
          on {{ $labels.host }}. The drive is reporting a serious fault and may fail
          imminently. Back up all data immediately.
        '';
      };
      data = mkPromData {
        expr = ''smartctl_device_smart_status{job="smartctl"}'';
        threshold = 1;
        thresholdType = "lt";
      };
    }

    {
      uid = "hw-disk-temperature";
      title = "Disk High Temperature";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "High disk temperature on {{ $labels.host }}: {{ $labels.device }}";
        description = ''
          Device {{ $labels.device }} on {{ $labels.host }} has been above 60°C for
          more than 5 minutes. Current temperature: {{ printf "%.0f" $values.B.Value }}°C.
          Check case airflow and cooling. Sustained high temperatures shorten drive lifespan.
        '';
      };
      data = mkPromData {
        expr = ''smartctl_device_temperature{job="smartctl"}'';
        threshold = 60;
      };
    }

    {
      uid = "hw-nvme-critical-warning";
      title = "NVMe Critical Warning";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "NVMe critical warning on {{ $labels.host }}: {{ $labels.device }}";
        description = ''
          NVMe device {{ $labels.device }} on {{ $labels.host }} has set a critical
          warning flag (bitmask value: {{ printf "%.0f" $values.B.Value }}).
          Possible causes: spare capacity below threshold, temperature out of range,
          NVM subsystem reliability degraded, media read-only, or volatile memory
          backup failed. Inspect drive immediately with `smartctl -a`.
        '';
      };
      data = mkPromData {
        expr = ''smartctl_device_critical_warning{job="smartctl"}'';
        threshold = 0;
      };
    }

    {
      uid = "hw-nvme-low-spare";
      title = "NVMe Available Spare Low";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "NVMe available spare below 10% on {{ $labels.host }}: {{ $labels.device }}";
        description = ''
          NVMe device {{ $labels.device }} on {{ $labels.host }} has only
          {{ printf "%.0f" $values.B.Value }}% available spare capacity remaining.
          When this reaches the spare threshold the drive will set a critical warning.
          Plan for replacement soon.
        '';
      };
      data = mkPromData {
        expr = ''smartctl_device_available_spare{job="smartctl"}'';
        threshold = 10;
        thresholdType = "lt";
      };
    }

    {
      uid = "hw-disk-space-low";
      title = "Low Disk Space";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Low disk space on {{ $labels.host }}: {{ $labels.mountpoint }}";
        description = ''
          Filesystem {{ $labels.mountpoint }} ({{ $labels.device }}) on {{ $labels.host }}
          has only {{ printf "%.1f" $values.B.Value }}% free space remaining.
          Excludes tmpfs, overlay, and squashfs filesystems.
        '';
      };
      data = mkPromData {
        expr = ''
          (
            node_filesystem_avail_bytes{
              job="node_exporter",
              fstype!~"tmpfs|ramfs|squashfs|fuse.*|overlay"
            }
            / node_filesystem_size_bytes{
              job="node_exporter",
              fstype!~"tmpfs|ramfs|squashfs|fuse.*|overlay"
            }
          ) * 100
        '';
        threshold = 10;
        thresholdType = "lt";
      };
    }

    {
      uid = "hw-node-offline";
      title = "Node Offline";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Node {{ $labels.host }} is offline";
        description = ''
          Node {{ $labels.host }} has not reported any metrics for more than 5 minutes.
          The host may be powered off, have lost network connectivity, or the Alloy
          agent may have crashed. Last seen: {{ $values.B.Value | int }} seconds ago.
        '';
      };
      # Returns a value only when a node has been silent for > 5 minutes.
      # A 30-minute lookback window ensures the alert fires for the full outage
      # duration rather than just the first few minutes after staleness kicks in.
      data = mkPromData {
        expr = ''
          (
            time()
            - timestamp(
                last_over_time(up{job="node_exporter"}[30m])
              )
          ) > 300
        '';
        threshold = 0;
        rangeFrom = 1800;
      };
    }
  ];
}
