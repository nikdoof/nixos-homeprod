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
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.lab.doofnet.uk." ];
  };
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
