{
  zlib,
  ...
}:
{
  zoneData = {
    SOA = zlib.mkSOA 2026032801;
    NS = zlib.internalNS;
    TTL = 3600;

    # Gateway
    subdomains."1.1".PTR = [ "gw.int.doofnet.uk." ];

    # Nameservers
    subdomains."2.1".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.1".PTR = [ "ns-02.int.doofnet.uk." ];

    # Infrastructure
    subdomains."16.3".PTR = [ "nas-03.int.doofnet.uk." ];

    # Service hosts
    subdomains."20.3".PTR = [ "svc-01.int.doofnet.uk." ];
    subdomains."21.3".PTR = [ "svc-02.int.doofnet.uk." ];
    subdomains."22.3".PTR = [ "hyp-01.int.doofnet.uk." ];

    # VMs
    subdomains."30.3".PTR = [ "afp-01.int.doofnet.uk." ];
  };
  dynamic.enable = true;
}
