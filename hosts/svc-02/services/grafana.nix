{ config, pkgs, ... }:
let
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
            path = dashboards;
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
