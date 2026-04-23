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
      refresh = 3600;
      retry = 900;
      expire = 604800;
      minimum = 300;
    };
    NS = [
      "ns-01.int.doofnet.uk."
      "ns-02.int.doofnet.uk."
    ];

    TTL = 3600;

    subdomains = {
      # Gateway (IPv6 only)
      gw.AAAA = [ "2001:8b0:bd9:105::1" ];
    };
  };
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
