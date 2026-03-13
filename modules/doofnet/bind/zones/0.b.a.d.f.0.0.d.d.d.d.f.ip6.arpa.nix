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
      serial = 2026031301;
    };
    NS = [
      "ns-01.int.doofnet.uk."
      "ns-02.int.doofnet.uk."
    ];

    TTL = 3600;

    # Infrastructure - VLAN101
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "gw.int.doofnet.uk." ];
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns-02.int.doofnet.uk." ];
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nas-03.int.doofnet.uk." ];
  };
}
