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
      serial = 2025030101;
    };
    NS = [
      "ns-01.int.doofnet.uk."
      "ns-02.int.doofnet.uk."
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
  extraConfig = ''
    allow-transfer { he-dns; };
  '';
}
