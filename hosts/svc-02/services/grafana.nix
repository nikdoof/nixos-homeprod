{ config, ... }:
{
  services.grafana = {
    enable = true;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        enforce_domain = false;
        enable_gzip = true;
        domain = "grafana.svc.doofnet.uk";
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
            path = "/etc/grafana/dashboards";
            foldersFromFilesStructure = true;
          };
        }
      ];

      datasources.settings.datasources = [
        {
          name = "prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
          editable = false;
        }
        {
          name = "loki";
          type = "loki";
          url = "https://loki.svc.doofnet.uk";
        }
      ];
    };
  };

  # Provision Grafana dashboards via /etc
  environment.etc = {
    "grafana/dashboards/bind.json".source = ./files/dashboards/bind.json;
    "grafana/dashboards/downloads.json".source = ./files/dashboards/downloads.json;
    "grafana/dashboards/house-dashboard.json".source = ./files/dashboards/house-dashboard.json;
    "grafana/dashboards/infra-dashboard.json".source = ./files/dashboards/infra-dashboard.json;
    "grafana/dashboards/jrouter.json".source = ./files/dashboards/jrouter.json;
    "grafana/dashboards/pfsense.json".source = ./files/dashboards/pfsense.json;
    "grafana/dashboards/postgresql-database.json".source = ./files/dashboards/postgresql-database.json;
    "grafana/dashboards/truenas-cgroups.json".source = ./files/dashboards/truenas-cgroups.json;
    "grafana/dashboards/truenas-disk-insight.json".source =
      ./files/dashboards/truenas-disk-insight.json;
    "grafana/dashboards/truenas-overview.json".source = ./files/dashboards/truenas-overview.json;
    "grafana/dashboards/truenas-temperatures.json".source =
      ./files/dashboards/truenas-temperatures.json;
    "grafana/dashboards/unifi_ap.json".source = ./files/dashboards/unifi_ap.json;
    "grafana/dashboards/unifi_clients.json".source = ./files/dashboards/unifi_clients.json;
    "grafana/dashboards/unifi_sites.json".source = ./files/dashboards/unifi_sites.json;
    "grafana/dashboards/unifi_usw.json".source = ./files/dashboards/unifi_usw.json;
    "grafana/dashboards/globaltalk.json".source = ./files/dashboards/globaltalk.json;
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
}
