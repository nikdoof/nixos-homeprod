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
    ];

    TTL = 3600;

    # Infrastructure - VLAN101
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "gw.int.doofnet.uk." ];
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns-02.int.doofnet.uk." ];
    subdomains."1.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nas-afp.int.doofnet.uk." ];
    subdomains."2.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "jrouter.int.doofnet.uk." ];
    subdomains."5.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "esx-01.int.doofnet.uk." ];
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nas-03.int.doofnet.uk." ];

    # Kubernetes Masters
    subdomains."3.1.0.0.0.1.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "prod-master-03.int.doofnet.uk." ];
  };
}
