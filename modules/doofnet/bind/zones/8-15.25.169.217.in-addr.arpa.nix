{
  zlib,
  ...
}:
{
  zoneData = {
    SOA = zlib.mkSOA 2026041001;
    NS = zlib.publicNS;
    TTL = 3600;

    # PTR records for delegated /29
    subdomains."9".PTR = [ "gw.doofnet.uk." ];
    subdomains."10".PTR = [ "web-01.doofnet.uk." ];
    subdomains."11".PTR = [ "mx-01.doofnet.uk." ];
    subdomains."13".PTR = [ "hs.doofnet.uk." ];
  };
}
