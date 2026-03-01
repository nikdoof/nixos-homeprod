{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "8-15.25.169.217.in-addr.arpa" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2024010100;
    };
    NS = dns_masters ++ [
      "ns1.he.net."
      "ns2.he.net."
      "ns3.he.net."
      "ns4.he.net."
    ];

    TTL = 3600;

    # PTR records for delegated /29
    subdomains."9".PTR = [ "gw.doofnet.uk." ];
    subdomains."10".PTR = [ "web-01.doofnet.uk." ];
    subdomains."11".PTR = [ "mx-01.doofnet.uk." ];
    subdomains."13".PTR = [ "hs.doofnet.uk." ];
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-transfer { key he-dns; };
  '';
}
