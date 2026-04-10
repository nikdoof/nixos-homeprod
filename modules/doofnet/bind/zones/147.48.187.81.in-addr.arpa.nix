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
      serial = 2026041001;
      refresh = 3600;
      retry = 900;
      expire = 604800;
      minimum = 300;
    };
    NS = [
      "ns-03.doofnet.uk."
      "ns-04.doofnet.uk."
    ];

    TTL = 3600;

    # Root of zone
    PTR = [ "gw.int.doofnet.uk." ];
  };
  extraConfig = "";
}
