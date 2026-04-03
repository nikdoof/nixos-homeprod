# Services alert group: HTTP probe health, TLS certificate expiry,
# systemd unit failures, and exporter availability.
mkPromData: {
  orgId = 1;
  name = "Services";
  folder = "Alerts";
  interval = "1m";
  rules = [
    {
      uid = "svc-http-probe-down";
      title = "HTTP Probe Down";
      condition = "C";
      for = "2m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "HTTP probe failing for {{ $labels.instance }}";
        description = ''
          Blackbox probe for {{ $labels.instance }} has been returning a non-2xx
          response or failing to connect for more than 2 minutes.
          Check the service is running and accessible from svc-02.
        '';
      };
      data = mkPromData {
        expr = ''probe_success{job="blackbox"}'';
        threshold = 1;
        thresholdType = "lt";
      };
    }

    {
      uid = "svc-ssl-cert-expiry";
      title = "TLS Certificate Expiring Soon";
      condition = "C";
      for = "0s";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "TLS certificate for {{ $labels.instance }} expires in {{ printf \"%.0f\" $values.B.Value }} days";
        description = ''
          The TLS certificate for {{ $labels.instance }} will expire in
          {{ printf "%.0f" $values.B.Value }} days. Renew via Let's Encrypt or
          check the ACME renewal process on the relevant host.
        '';
      };
      data = mkPromData {
        expr = ''
          (probe_ssl_earliest_cert_expiry{job="blackbox"} - time()) / 86400
        '';
        threshold = 14;
        thresholdType = "lt";
      };
    }

    {
      uid = "svc-systemd-failed";
      title = "Systemd Service Failed";
      condition = "C";
      for = "2m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "critical";
      annotations = {
        summary = "Systemd unit failed on {{ $labels.host }}: {{ $labels.name }}";
        description = ''
          Systemd unit {{ $labels.name }} on {{ $labels.host }} has been in a
          failed state for more than 2 minutes. Run `systemctl status {{ $labels.name }}`
          and `journalctl -u {{ $labels.name }}` on the host to investigate.
        '';
      };
      # Filters to type=service to avoid noise from transient sockets and paths.
      data = mkPromData {
        expr = ''
          node_systemd_unit_state{
            job="node_exporter",
            state="failed",
            type="service"
          }
        '';
        threshold = 0;
      };
    }

    {
      uid = "svc-fail2ban-high-bans";
      title = "fail2ban High Active Ban Count";
      condition = "C";
      for = "10m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.host }} has more than 10 active fail2ban bans in jail {{ $labels.jail }}";
        description = ''
          fail2ban jail {{ $labels.jail }} on {{ $labels.host }} currently has
          more than 10 IPs banned, sustained for 10 minutes. This may indicate
          an active credential-stuffing or brute-force campaign.
          Current ban count: {{ printf "%.0f" $values.B.Value }}.
          Check with `fail2ban-client status {{ $labels.jail }}` on the host.
        '';
      };
      data = mkPromData {
        expr = "fail2ban_banned_ips";
        threshold = 10;
      };
    }

    {
      uid = "svc-exporter-down";
      title = "Exporter Scrape Failing";
      condition = "C";
      for = "5m";
      noDataState = "OK";
      execErrState = "Error";
      labels.severity = "warning";
      annotations = {
        summary = "Exporter scrape failing: {{ $labels.job }} on {{ $labels.host }}";
        description = ''
          Alloy has been unable to scrape the {{ $labels.job }} exporter on
          {{ $labels.host }} for more than 5 minutes. The exporter process may
          have crashed or the service it monitors may be unavailable.
          Check with `systemctl status` for the relevant exporter service.
        '';
      };
      # Excludes prometheus self-scrape (always pulled directly, not via remote_write).
      data = mkPromData {
        expr = ''up{job!="prometheus"}'';
        threshold = 1;
        thresholdType = "lt";
      };
    }
  ];
}
