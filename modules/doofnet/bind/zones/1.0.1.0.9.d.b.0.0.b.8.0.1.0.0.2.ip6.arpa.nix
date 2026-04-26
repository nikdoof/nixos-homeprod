{
  zlib,
  ...
}:
# VLAN 101 reverse: 2001:8b0:bd9:101::/64
{
  zoneData = {
    SOA = zlib.mkSOA 2026041001;
    NS = zlib.publicNS;
    TTL = 3600;

    # Gateway
    subdomains."1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "gw.doofnet.uk." ];

    # Nameservers
    subdomains."2.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "ns-02.int.doofnet.uk." ];

    # Infrastructure
    subdomains."6.1.0.0.0.0.0.0.0.0.0.0.0.0.0.0".PTR = [ "nas-03.int.doofnet.uk." ];
  };
  dynamic.enable = true;
}
