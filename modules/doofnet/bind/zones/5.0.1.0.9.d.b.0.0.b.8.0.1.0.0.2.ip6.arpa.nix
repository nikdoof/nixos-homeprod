{
  zlib,
  ...
}:
# VLAN 105 reverse: 2001:8b0:bd9:105::/64 (HA / IoT)
{
  zoneData = {
    SOA = zlib.mkSOA 2025030101;
    NS = zlib.publicNS;
    TTL = 3600;

    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.ha.doofnet.uk." ];
  };
  dynamic.enable = true;
}
