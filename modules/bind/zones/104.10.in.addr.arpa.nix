{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "104.10.in-addr.arpa" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters;

    TTL = 3600;

    # Gateway
    subdomains."1.1".PTR = [ "gw.lab.doofnet.uk." ];
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
