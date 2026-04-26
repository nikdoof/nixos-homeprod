{
  zlib,
  ...
}:
{
  zoneData = {
    SOA = zlib.mkSOA 2025030101;
    NS = zlib.internalNS;
    TTL = 3600;

    subdomains."1.1".PTR = [ "gw.lab.doofnet.uk." ];
  };
  dynamic.enable = true;
}
