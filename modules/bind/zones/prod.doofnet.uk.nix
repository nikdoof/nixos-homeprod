{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "prod.doofnet.uk" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters;

    TTL = 3600;

    subdomains = {
      # Wildcard for Kubernetes ingress
      "*".A = [ "10.101.10.6" ];
    };
  };
  slaves = dns_slaves;
}
