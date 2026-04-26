{
  zlib,
  ...
}:
{
  zoneData = {
    SOA = zlib.mkSOA 2025030101;
    NS = zlib.internalNS;
    TTL = 3600;

    subdomains = {
      # IPv6 only
      gw.AAAA = [ "2001:8b0:bd9:105::1" ];
    };
  };
  dynamic.enable = true;
}
