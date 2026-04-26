{
  zlib,
  ...
}:
{
  zoneData = {
    SOA = zlib.mkSOA 2025030301;
    NS = zlib.internalNS;
    TTL = 300;

    subdomains = {
      # Wildcard for container services
      "*".A = [ "10.101.3.20" ];

      # Specific services
      grafana.A = [ "10.101.3.21" ];
      unifi.A = [ "10.101.3.21" ];
      loki.A = [ "10.101.3.21" ];
      prometheus.A = [ "10.101.3.21" ];
    };
  };
}
