{
  pkgs,
  ...
}:
{
  services.postgresql = {
    enable = true;
    enableTCPIP = true;
    dataDir = "/srv/data/postgresql";
    settings = {
      port = 5432;
      ssl = true;
    };

    # Allow local auth via scram
    authentication = pkgs.lib.mkAfter ''
      local all all trust
      host sameuser all 127.0.0.1/32 scram-sha-256
      host sameuser all ::1/128 scram-sha-256
    '';
  };

  services.prometheus.exporters.postgres = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9187;
  };

  environment.etc."alloy/conf.d/02-postgres.alloy".text = ''
    prometheus.scrape "postgres" {
      targets    = [{"__address__" = "localhost:9187"}]
      forward_to = [prometheus.remote_write.default.receiver]
      job_name   = "postgres"
    }
  '';

  networking.firewall = {
    allowedTCPPorts = [
      5432
    ];
  };

  services.borgmatic.settings.postgresql_databases = [
    {
      name = "all";
      compression = "zstd";
    }
  ];
}
