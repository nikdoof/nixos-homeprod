{
  dns,
  ...
}:
with dns.lib.combinators;
{
  # Special-Use Domain Names space (RFC 6761) and is intended for local resolution only
  # hence the blank domain
  zoneData = {
    SOA = {
      nameServer = "ns-01.int.doofnet.uk.";
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2026031301;
      refresh = 3600;
      retry = 900;
      expire = 604800;
      minimum = 300;
    };

    NS = [
      "ns-01.int.doofnet.uk."
      "ns-02.int.doofnet.uk."
    ];
  };
}
