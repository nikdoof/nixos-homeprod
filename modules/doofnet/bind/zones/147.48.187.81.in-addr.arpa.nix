{
  zlib,
  ...
}:
{
  zoneData = {
    SOA = zlib.mkSOA 2026041001;
    NS = zlib.publicNS;
    TTL = 3600;

    # Root of zone (single PPPoE WAN address)
    PTR = [ "gw.int.doofnet.uk." ];
  };
}
