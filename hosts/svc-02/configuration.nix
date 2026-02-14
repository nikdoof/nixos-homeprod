{
  config,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../hardware/prodesk-600-g3-dm.nix
    ../../modules/common.nix
    ../../modules/server.nix
    ../../modules/traefik.nix
    ../../modules/nfs/media.nix
  ];

  # Allows for cross compling for Pis
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  nix.settings.extra-platforms = [
    "aarch64-linux"
    "arm-linux"
  ];

  # Networking
  networking.useDHCP = false;
  networking.hostName = "svc-02";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  networking.domain = "int.doofnet.uk";
  networking.search = [ "int.doofnet.uk" ];
  systemd.network.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Name = "eno1";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  services.prometheus = {
    enable = true;

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
    ];
  };

  # Bind Prometheus home folder to the NVMe.
  fileSystems."/var/lib/prometheus2" = {
    device = "/srv/data/prometheus/data";
    options = [ "bind" ];
  };

  networking.firewall.allowedTCPPorts = [
    9090
  ];

  services.grafana = {
    enable = true;
    openFirewall = true;

    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        enforce_domain = false;
        enable_gzip = true;
        domain = "svc-02.int.doofnet.uk";
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
          url = "http://${config.services.prometheus.listenAddress}:${toString config.services.prometheus.port}";
          isDefault = true;
          editable = false;
        }
      ];
    };
  };

  # Provision Grafana dashboards via /etc
  environment.etc = {
    "grafana/dashboards/bind.json".source = ./grafana/dashboards/bind.json;
    "grafana/dashboards/downloads.json".source = ./grafana/dashboards/downloads.json;
    "grafana/dashboards/house-dashboard.json".source = ./grafana/dashboards/house-dashboard.json;
    "grafana/dashboards/infra-dashboard.json".source = ./grafana/dashboards/infra-dashboard.json;
    "grafana/dashboards/jrouter.json".source = ./grafana/dashboards/jrouter.json;
    "grafana/dashboards/mosquitto-broker.json".source = ./grafana/dashboards/mosquitto-broker.json;
    "grafana/dashboards/pfsense.json".source = ./grafana/dashboards/pfsense.json;
    "grafana/dashboards/postgresql-database.json".source =
      ./grafana/dashboards/postgresql-database.json;
    "grafana/dashboards/truenas-cgroups.json".source = ./grafana/dashboards/truenas-cgroups.json;
    "grafana/dashboards/truenas-disk-insight.json".source =
      ./grafana/dashboards/truenas-disk-insight.json;
    "grafana/dashboards/truenas-overview.json".source = ./grafana/dashboards/truenas-overview.json;
    "grafana/dashboards/truenas-temperatures.json".source =
      ./grafana/dashboards/truenas-temperatures.json;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
