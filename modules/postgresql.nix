{
  pkgs,
  config,
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

      # Slow query logging
      log_min_duration_statement = 1000;

      # Lock/deadlock visibility
      log_lock_waits = true;
      deadlock_timeout = "1s";

      # Temp file spill detection
      log_temp_files = 0;

      # Autovacuum and checkpoint observability
      log_autovacuum_min_duration = 0;
      log_checkpoints = true;

      # NVMe-tuned I/O settings
      random_page_cost = "1.1";
      effective_io_concurrency = 200;

      # Memory - capped at ~30% of 16GB system RAM
      shared_buffers = "4GB";
      effective_cache_size = "8GB";
      work_mem = "32MB";
      maintenance_work_mem = "256MB";

      # WAL/checkpoint tuning
      checkpoint_completion_target = "0.9";
      max_wal_size = "4GB";

      # Query statistics
      shared_preload_libraries = "pg_stat_statements";
    };

    ensureUsers = [
      {
        name = "nikdoof";
        ensureDBOwnership = false;
      }
    ];

    # Allow local auth via scram
    authentication = pkgs.lib.mkAfter ''
      local all all trust
      host sameuser all 127.0.0.1/32 scram-sha-256
      host sameuser all ::1/128 scram-sha-256

      # Remote admin access via PAM
      host all nikdoof 10.101.0.0/16 pam
      host all nikdoof 2001:8b0:bd9:101::/64 pam
    '';
  };

  security.pam.services.postgresql = { };

  systemd.services.postgresql-stat-statements = {
    description = "Enable pg_stat_statements on all PostgreSQL databases";
    after = [ "postgresql.service" ];
    wants = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      ExecStart = pkgs.writeShellScript "pg-stat-statements" ''
        ${config.services.postgresql.package}/bin/psql -tc \
          "SELECT datname FROM pg_database WHERE datistemplate = false" \
          | while IFS= read -r db; do
              [ -z "''${db// }" ] && continue
              ${config.services.postgresql.package}/bin/psql -d "$db" -c \
                "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
            done
      '';
    };
  };

  services.prometheus.exporters.postgres = {
    enable = true;
    listenAddress = "127.0.0.1";
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
