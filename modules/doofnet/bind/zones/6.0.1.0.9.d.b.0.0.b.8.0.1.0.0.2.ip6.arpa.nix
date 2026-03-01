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

    # Gateway
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.doofnet.uk." ];
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "web-01.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "mx-01.doofnet.uk." ];
    subdomains."3.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "hs.doofnet.uk." ];
  };
  extraConfig = ''
    allow-transfer {
      10.101.1.3;
      2001:8b0:bd9:101::3;
      he-dns;
    };
    allow-update { doofnet-dhcp-updates; };
  '';
}
