{ config, ... }:
{
  services.prometheus = {
    enable = true;

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
            targets = [
              "gw.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "ns1.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "ns2.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "svc-01.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "svc-02.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "nas-afp.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "jrouter.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "nexus.int.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"

              "web-01.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "mx-01.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
              "hs.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
      {
        job_name = "jrouter";
        static_configs = [
          {
            targets = [
              "jrouter.int.doofnet.uk:9459"
            ];
          }
        ];
      }
      {
        job_name = "bind";
        static_configs = [
          {
            targets = [
              "ns1.int.doofnet.uk:9119"
              "ns2.int.doofnet.uk:9119"
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
            targets = [ "127.0.0.1:9090" ];
          }
        ];
      }
      {
        job_name = "grafana";
        static_configs = [
          {
            targets = [ "127.0.0.1:3000" ];
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
    ];
  };

  networking.firewall = {
    allowedTCPPorts = [
      9090 # Prometheus
    ];
  };

  # Bind Prometheus home folder to the NVMe.
  fileSystems."/var/lib/prometheus2" = {
    device = "/srv/data/prometheus/data";
    options = [ "bind" ];
  };
}
