{
  zlib,
  ...
}:
# VLAN 102 reverse: 2001:8b0:bd9:102::/64 (pub)
{
  zoneData = {
    SOA = zlib.mkSOA 2026042601;
    NS = zlib.publicNS;
    TTL = 3600;

    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.pub.doofnet.uk." ];
  };
  dynamic.enable = true;
}
