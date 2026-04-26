{
  zlib,
  ...
}:
# VLAN 106 reverse: 2001:8b0:bd9:106::/64 (hosted)
{
  zoneData = {
    SOA = zlib.mkSOA 2026041001;
    NS = zlib.publicNS;
    TTL = 3600;

    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.doofnet.uk." ];
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "web-01.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "mx-01.doofnet.uk." ];
    subdomains."3.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "hs.doofnet.uk." ];
  };
  dynamic.enable = true;
}
