{
  dns,
  ...
}:
with dns.lib.combinators;
{
  zoneData = {
    SOA = {
      nameServer = "ns-01.int.doofnet.uk.";
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030301;
    };
    NS = [
      "ns-01.int.doofnet.uk."
      "ns-02.int.doofnet.uk."
    ];

    TTL = 300;

    subdomains = {
      # Wildcard for container services
      "*".A = [ "10.101.3.20" ];

      # Specific services
      grafana.A = [ "10.101.3.21" ];
      unifi.A = [ "10.101.3.21" ];
      loki.A = [ "10.101.3.21" ];
    };
  };
}
