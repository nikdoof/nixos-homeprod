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

    subdomains = {
      # Gateway
      gw = host "10.102.1.1" "2001:8b0:bd9:102::1";
    };
  };
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
