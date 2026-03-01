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

    # Nameservers
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "ns-02.int.doofnet.uk." ];

    # Infrastructure
    subdomains."1.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "nas-afp.int.doofnet.uk." ];
    subdomains."2.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "jrouter.int.doofnet.uk." ];
    subdomains."5.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "esx-01.int.doofnet.uk." ];
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "nas-03.int.doofnet.uk." ];

    # Kubernetes Masters
    subdomains."3.1.0.0.0.1.0.0.0.0.0.0.0.0.0.0".PTR = [ "prod-master-03.int.doofnet.uk." ];
  };
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
