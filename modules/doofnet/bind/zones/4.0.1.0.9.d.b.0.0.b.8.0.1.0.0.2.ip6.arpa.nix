{
  zlib,
  ...
}:
# VLAN 104 reverse: 2001:8b0:bd9:104::/64
{
  zoneData = {
    SOA = zlib.mkSOA 2026041001;
    NS = zlib.publicNS;
    TTL = 3600;

    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.lab.doofnet.uk." ];
  };
  dynamic.enable = true;
}
