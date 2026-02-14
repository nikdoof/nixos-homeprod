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
    ../../modules/nfs/media.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 2;
    efi.canTouchEfiVariables = true;
  };

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
              "hs-01.doofnet.uk:${toString config.services.prometheus.exporters.node.port}"
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

  services.grafana = {
    enable = true;
  };

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
