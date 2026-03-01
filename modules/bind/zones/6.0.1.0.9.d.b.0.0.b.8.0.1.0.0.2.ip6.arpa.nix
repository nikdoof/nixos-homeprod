{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "6.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa" {
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
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "web-01.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "mx-01.doofnet.uk." ];
    subdomains."3.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "hs.doofnet.uk." ];
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-transfer { he-dns; };
    allow-update { doofnet-dhcp-updates; };
  '';
}
