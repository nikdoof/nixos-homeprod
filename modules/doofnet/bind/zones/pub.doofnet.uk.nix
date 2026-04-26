{
  dns,
  zlib,
  ...
}:
with dns.lib.combinators;
{
  zoneData = {
    SOA = zlib.mkSOA 2025030101;
    NS = zlib.internalNS;
    TTL = 3600;

    subdomains = {
      gw = host "10.102.1.1" "2001:8b0:bd9:102::1";
    };
  };
  dynamic.enable = true;
}
