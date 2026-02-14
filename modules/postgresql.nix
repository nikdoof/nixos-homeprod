{
  ...
}:

{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    dataDir = "/srv/data/postgresql";
    port = 5432;
    settings = {
      ssl = true;
    };
  };

  services.prometheus.exporters.postgres = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9187;
  };

  networking.firewall.allowedTCPPorts = [
    5432
    9187
  ];
}
