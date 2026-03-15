{
  config,
  inputs,
  lib,
  ...
}:
let
  # For every nixosConfiguration that has doofnet.server enabled, read the
  # hostname, domain, and node_exporter port from its evaluated config and
  # build a "host.domain:port" scrape target string.
  nodeExporterTargets =
    let
      allConfigs = lib.mapAttrsToList (name: nixos: {
        inherit name;
        cfg = nixos.config;
      }) inputs.self.nixosConfigurations;

      serverHosts = builtins.filter (h: h.cfg.doofnet.server) allConfigs;
    in
    map (
      h:
      "${h.cfg.networking.hostName}.${h.cfg.networking.domain}:${toString h.cfg.services.prometheus.exporters.node.port}"
    ) serverHosts;

  # Hosts running node_exporter that are not managed by this flake.
  extraNodeTargets = [
    "gw.int.doofnet.uk:9100"
  ];
in
{
  services.prometheus = {
    enable = true;
    listenAddress = "0.0.0.0";

    enableReload = true;
    retentionTime = "365d";

    alertmanagers = [
      {
        scheme = "https";
        static_configs = [
          {
            targets = [
              "127.0.0.1:${toString config.services.prometheus.alertmanager.port}"
            ];
          }
        ];
      }
    ];

    scrapeConfigs = [
      {
        job_name = "node_exporter";
        static_configs = [
          {
            targets = nodeExporterTargets ++ extraNodeTargets;
          }
        ];
      }
      {
        job_name = "jrouter";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9459"
            ];
          }
        ];
      }
      {
        job_name = "bind";
        static_configs = [
          {
            targets = [
              "ns-01.int.doofnet.uk:9119"
              "ns-02.int.doofnet.uk:9119"
            ];
          }
        ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {
            targets = [
              "svc-01.int.doofnet.uk:9187"
              "svc-02.int.doofnet.uk:9187"
            ];
          }
        ];
      }
      {
        job_name = "unifi";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9130"
            ];
          }
        ];
      }
      {
        job_name = "graphite";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9108"
            ];
          }
        ];
      }
      {
        job_name = "homeassistant";
        metrics_path = "/api/prometheus";
        scheme = "https";
        static_configs = [
          {
            targets = [ "homeassistant.int.doofnet.uk:443" ];
          }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.prometheus.port}" ];
          }
        ];
      }
      {
        job_name = "grafana";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.grafana.settings.server.http_port}" ];
          }
        ];
      }
      {
        job_name = "loki";
        static_configs = [
          {
            targets = [ "127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}" ];
          }
        ];
      }
      {
        job_name = "hcloud";
        static_configs = [
          {
            targets = [ "127.0.0.1:9501" ];
          }
        ];
      }
      {
        job_name = "traefik";
        static_configs = [
          {
            targets = [
              "svc-01.int.doofnet.uk:9871"
              "svc-02.int.doofnet.uk:9871"
            ];
          }
        ];
      }
      {
        job_name = "headscale";
        static_configs = [
          {
            targets = [
              "hs.doofnet.uk:9090"
            ];
          }
        ];
      }
    ];
  };

  services.traefik = {
    dynamicConfigOptions = {
      http = {
        routers.prometheus = {
          rule = "Host(`prometheus.svc.doofnet.uk`)";
          service = "prometheus";
        };

        services.prometheus.loadBalancer.servers = [
          {
            url = "http://localhost:${toString config.services.prometheus.port}";
          }
        ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ config.services.prometheus.port ];

  # Bind Prometheus data directory to the NVMe.
  fileSystems."/var/lib/prometheus2" = {
    device = "/srv/data/prometheus/data";
    options = [ "bind" ];
  };
}
