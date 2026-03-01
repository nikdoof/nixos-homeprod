{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "0.b.a.d.f.0.0.d.d.d.d.f.ip6.arpa" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters;

    TTL = 3600;

    # Infrastructure - VLAN101
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "gw.int.doofnet.uk." ];
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns1.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns2.int.doofnet.uk." ];
    subdomains."0.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nexus.int.doofnet.uk." ];
    subdomains."1.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nas-afp.int.doofnet.uk." ];
    subdomains."2.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "jrouter.int.doofnet.uk." ];
    subdomains."5.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "esx-01.int.doofnet.uk." ];
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nas-03.int.doofnet.uk." ];

    # Kubernetes Masters
    subdomains."3.1.0.0.0.1.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "prod-master-03.int.doofnet.uk." ];
  };
  slaves = dns_slaves;
}
