{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "147.48.187.81.in-addr.arpa" {
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

    # Root of zone
    PTR = [ "gw.int.doofnet.uk." ];
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-transfer { key he-dns; };
  '';
}
