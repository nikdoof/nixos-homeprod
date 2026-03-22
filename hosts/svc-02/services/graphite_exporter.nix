_: {
  environment.etc."alloy/conf.d/02-graphite.alloy".text = ''
    prometheus.scrape "graphite" {
      targets    = [{"__address__" = "127.0.0.1:9108"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "graphite"
    }
  '';

  services.prometheus.exporters = {
    graphite = {
      enable = true;
      mappingSettings = builtins.fromJSON (builtins.readFile ./files/truenas_mapping.json);
    };
  };

  # The graphite incoming port
  networking.firewall = {
    allowedTCPPorts = [
      9109
    ];
    allowedUDPPorts = [
      9109
    ];
  };
}
