{
  dns,
  ...
}:
with dns.lib.combinators;
{
  zoneData = {
    SOA = {
      nameServer = "ns-01.int.doofnet.uk.";
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = [
      "ns-01.int.doofnet.uk."
      "ns-02.int.doofnet.uk."
    ];

    TTL = 3600;

    # Gateway
    subdomains."1.1".PTR = [ "gw.int.doofnet.uk." ];

    # Nameservers
    subdomains."2.1".PTR = [ "ns-01.int.doofnet.uk." ];
    subdomains."3.1".PTR = [ "ns-02.int.doofnet.uk." ];

    # Infrastructure
    subdomains."11.3".PTR = [ "nas-afp.int.doofnet.uk." ];
    subdomains."15.3".PTR = [ "esx-01.int.doofnet.uk." ];
    subdomains."16.3".PTR = [ "nas-03.int.doofnet.uk." ];

    # Service hosts
    subdomains."20.3".PTR = [ "svc-01.int.doofnet.uk." ];
    subdomains."21.3".PTR = [ "svc-01.int.doofnet.uk." ];
    subdomains."22.3".PTR = [ "hyp-01.int.doofnet.uk." ];

    # VMs
    subdomains."30.3".PTR = [ "afp-01.int.doofnet.uk." ];

    # Kubernetes Masters
    subdomains."13.10".PTR = [ "prod-master-03.int.doofnet.uk." ];
  };
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
