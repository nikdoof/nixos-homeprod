{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "101.10.in-addr.arpa" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters;

    TTL = 3600;

    # Gateway
    subdomains."1.1".PTR = [ "gw.int.doofnet.uk." ];

    # Nameservers
    subdomains."2.1".PTR = [ "ns1.int.doofnet.uk." ];
    subdomains."3.1".PTR = [ "ns2.int.doofnet.uk." ];

    # Infrastructure
    subdomains."10.3".PTR = [ "nexus.int.doofnet.uk." ];
    subdomains."11.3".PTR = [ "nas-afp.int.doofnet.uk." ];
    subdomains."12.3".PTR = [ "jrouter.int.doofnet.uk." ];
    subdomains."15.3".PTR = [ "esx-01.int.doofnet.uk." ];
    subdomains."16.3".PTR = [ "nas-03.int.doofnet.uk." ];

    # Service hosts
    subdomains."20.3".PTR = [ "svc-01.int.doofnet.uk." ];
    subdomains."21.3".PTR = [ "svc-01.int.doofnet.uk." ];
    subdomains."22.3".PTR = [ "hyp-01.int.doofnet.uk." ];

    # Kubernetes Masters
    subdomains."13.10".PTR = [ "prod-master-03.int.doofnet.uk." ];
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-update { key doofnet-dhcp-updates; };
  '';
}
