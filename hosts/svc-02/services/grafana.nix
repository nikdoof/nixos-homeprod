{ config, pkgs, ... }:
let
  secretPath = config.age.secrets.grafanaOidcClientSecret.path;
  telegramTokenPath = config.age.secrets.grafanaTelegramToken.path;

  # Builds the standard Prometheus A=query / B=reduce / C=threshold data structure
  # used by Grafana unified alerting rules.
  mkPromData =
    {
      expr,
      threshold,
      thresholdType ? "gt",
      rangeFrom ? 600,
    }:
    [
      {
        refId = "A";
        datasourceUid = "prometheus";
        queryType = "";
        relativeTimeRange = {
          from = rangeFrom;
          to = 0;
        };
        model = {
          refId = "A";
          instant = true;
          inherit expr;
          datasource = {
            type = "prometheus";
            uid = "prometheus";
          };
        };
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        model = {
          refId = "B";
          type = "reduce";
          expression = "A";
          reducer = "last";
          datasource = {
            type = "__expr__";
            uid = "__expr__";
          };
        };
      }
      {
        refId = "C";
        datasourceUid = "__expr__";
        model = {
          refId = "C";
          type = "threshold";
          expression = "B";
          datasource = {
            type = "__expr__";
            uid = "__expr__";
          };
          conditions = [
            {
              evaluator = {
                params = [ threshold ];
                type = thresholdType;
              };
              operator.type = "and";
              query.params = [ "B" ];
              reducer.type = "last";
              type = "query";
            }
          ];
        };
      }
    ];

  dashboards = pkgs.stdenv.mkDerivation {
    name = "grafana-dashboards";
    src = ./files/dashboards;
    phases = [
      "unpackPhase"
      "installPhase"
    ];
    installPhase = ''
      mkdir -p $out
      cp -r $src/* $out
    '';
  };
in
{
  age.secrets.grafanaOidcClientSecret = {
    file = ../../../secrets/grafanaOidcClientSecret.age;
    owner = "grafana";
  };

  age.secrets.grafanaTelegramToken = {
    file = ../../../secrets/alertManagerTelegramToken.age;
    owner = "grafana";
  };

  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        enforce_domain = false;
        enable_gzip = true;
        domain = "grafana.svc.doofnet.uk";
        root_url = "https://grafana.svc.doofnet.uk";
      };
      smtp = {
        enabled = true;
        from_address = "grafana@doofnet.uk";
        host = "mx-01.doofnet.uk";
        startTLS_policy = "OpportunisticStartTLS";
      };
      analytics = {
        reporting_enabled = false;
        feedback_links_enabled = false;
      };
      auth = {
        disable_login_form = false;
        oauth_auto_login = false;
      };
      "auth.generic_oauth" = {
        enabled = true;
        name = "Pocket ID";
        client_id = "590ca225bf4cd85c2d4c4f65a38067b096675715";
        client_secret = "$__file{${secretPath}}";
        scopes = "openid profile email groups";
        auth_url = "https://id.doofnet.uk/authorize";
        token_url = "https://id.doofnet.uk/api/oidc/token";
        api_url = "https://id.doofnet.uk/api/oidc/userinfo";
        use_pkce = true;
        use_refresh_token = true;
        email_attribute_path = "email";
        login_attribute_path = "preferred_username";
        name_attribute_path = "name";
        role_attribute_path = "contains(groups[*], 'admin') && 'Admin' || 'Viewer'";
      };
    };

    provision = {
      enable = true;

      # Creates a *mutable* dashboard provider, pulling from /etc/grafana-dashboards.
      # With this, you can manually provision dashboards from JSON with `environment.etc` like below.
      dashboards.settings.providers = [
        {
          name = "Dashboards";
          disableDeletion = true;
          options = {
            path = dashboards;
            foldersFromFilesStructure = true;
          };
        }
      ];

      alerting.rules.settings.groups = [
        {
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
              # The expression returns a value only when a node has been silent for > 5 minutes.
              # A 30-minute lookback window ensures the alert fires for the full outage duration
              # rather than just the first 5 minutes after staleness kicks in.
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

        {
          orgId = 1;
          name = "GlobalTalk";
          folder = "Alerts";
          interval = "5m";
          rules = [
            {
              uid = "atalkd-net-mismatch";
              title = "GlobalTalk network collision";
              condition = "C";
              for = "0s";
              noDataState = "OK";
              execErrState = "Error";
              annotations.summary = "AppleTalk daemon on afp-01 is reporting a network collision.";
              data = [
                {
                  refId = "A";
                  datasourceUid = "loki";
                  queryType = "instant";
                  relativeTimeRange = {
                    from = 300;
                    to = 0;
                  };
                  model = {
                    refId = "A";
                    queryType = "instant";
                    datasource = {
                      type = "loki";
                      uid = "loki";
                    };
                    expr = ''count(rate({host="afp-01", unit="atalkd.service"} |~ `rtmp_packet (last|first)net mismatch (\d*)!=(\d*)` [5m]))'';
                  };
                }
                {
                  refId = "B";
                  datasourceUid = "__expr__";
                  model = {
                    refId = "B";
                    type = "reduce";
                    expression = "A";
                    reducer = "last";
                    datasource = {
                      type = "__expr__";
                      uid = "__expr__";
                    };
                  };
                }
                {
                  refId = "C";
                  datasourceUid = "__expr__";
                  model = {
                    refId = "C";
                    type = "threshold";
                    expression = "B";
                    datasource = {
                      type = "__expr__";
                      uid = "__expr__";
                    };
                    conditions = [
                      {
                        evaluator = {
                          params = [ 1 ];
                          type = "gt";
                        };
                        operator = {
                          type = "and";
                        };
                        query = {
                          params = [ "B" ];
                        };
                        reducer = {
                          type = "last";
                        };
                        type = "query";
                      }
                    ];
                  };
                }
              ];
            }
          ];
        }
      ];

      alerting.contactPoints.settings = {
        contactPoints = [
          {
            name = "Telegram";
            receivers = [
              {
                uid = "telegram-main";
                type = "telegram";
                settings = {
                  botToken = "$__file{${telegramTokenPath}}";
                  chatID = "-655795395";
                  parseMode = "HTML";
                };
              }
            ];
          }
        ];
        deleteContactPoints = [
          {
            orgId = 1;
            uid = "grafana-default-email";
          }
        ];
      };

      alerting.policies.settings = {
        policies = [
          {
            orgId = 1;
            receiver = "Telegram";
          }
        ];
      };

      datasources.settings.datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          uid = "prometheus";
          access = "proxy";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
          editable = false;
        }
        {
          name = "loki";
          type = "loki";
          uid = "loki";
          url = "https://loki.svc.doofnet.uk";
        }
      ];
    };
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.grafana = {
          rule = "Host(`grafana.svc.doofnet.uk`)";
          service = "grafana";
        };

        services.grafana.loadBalancer.servers = [
          { url = "http://localhost:${toString config.services.grafana.settings.server.http_port}"; }
        ];
      };
    };
  };

  # Alloy config
  environment.etc."alloy/conf.d/02-grafana.alloy".text = ''
    prometheus.scrape "grafana" {
      targets    = [{"__address__" = "127.0.0.1:${toString config.services.grafana.settings.server.http_port}"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "grafana"
    }
  '';
}
