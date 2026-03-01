{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "svc.doofnet.uk" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters;

    TTL = 3600;

    subdomains = {
      # Wildcard for container services
      "*".A = [ "10.101.3.20" ];

      # Specific services
      grafana.A = [ "10.101.3.21" ];
      unifi.A = [ "10.101.3.21" ];
    };
  };
  slaves = dns_slaves;
}
