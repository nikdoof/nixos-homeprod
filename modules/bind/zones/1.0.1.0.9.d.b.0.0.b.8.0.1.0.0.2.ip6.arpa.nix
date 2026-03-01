{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "1.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters ++ [
      "ns1.he.net."
      "ns2.he.net."
      "ns3.he.net."
      "ns4.he.net."
    ];

    TTL = 3600;

    # Gateway
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.doofnet.uk." ];

    # Nameservers
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "ns1.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "ns2.int.doofnet.uk." ];

    # Infrastructure
    subdomains."0.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "nexus.int.doofnet.uk." ];
    subdomains."1.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "nas-afp.int.doofnet.uk." ];
    subdomains."2.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "jrouter.int.doofnet.uk." ];
    subdomains."5.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "esx-01.int.doofnet.uk." ];
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "nas-03.int.doofnet.uk." ];

    # Kubernetes Masters
    subdomains."3.1.0.0.0.1.0.0.0.0.0.0.0.0.0.0".PTR = [ "prod-master-03.int.doofnet.uk." ];
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-transfer { he-dns; };
    allow-update { doofnet-dhcp-updates; };
  '';
}
