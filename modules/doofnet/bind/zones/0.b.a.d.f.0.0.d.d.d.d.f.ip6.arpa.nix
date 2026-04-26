{
  zlib,
  ...
}:
# ULA reverse: fddd:d00f:dab0::/48
{
  zoneData = {
    SOA = zlib.mkSOA 2026031301;
    NS = zlib.internalNS;
    TTL = 3600;

    # VLAN 101
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "gw.int.doofnet.uk." ];
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "ns-02.int.doofnet.uk." ];
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.1.0.1.0".PTR = [ "nas-03.int.doofnet.uk." ];
  };
}
