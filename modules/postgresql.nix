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
      host sameuser all 127.0.0.1/32 scram-sha-256
      host sameuser all ::1/128 scram-sha-256
    '';
  };

  services.prometheus.exporters.postgres = {
    enable = true;
    listenAddress = "0.0.0.0";
    port = 9187;
  };

  networking.firewall = {
    allowedTCPPorts = [
      5432
      9187
    ];
    extraCommands = ''
      # Allow PostgreSQL metrics port from Prometheus system
      iptables -A INPUT -p tcp --dport 9187 -s 10.101.0.0/16 -j ACCEPT -m comment --comment "Prometheus access to PostgreSQL metrics"
      ip6tables -A INPUT -p tcp --dport 9187 -s fddd:d00f:dab0:101::/64 -j ACCEPT -m comment --comment "Prometheus access to PostgreSQL metrics"
      ip6tables -A INPUT -p tcp --dport 9187 -s 2001:8b0:bd9:101::21/64 -j ACCEPT -m comment --comment "Prometheus access to PostgreSQL metrics"
    '';
  };
}
