{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "pub.doofnet.uk" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2025030101;
    };
    NS = dns_masters;

    TTL = 3600;

    subdomains = {
      # Gateway
      gw = host "10.102.1.1" "2001:8b0:bd9:102::1";
    };
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-update { key doofnet-dhcp-updates; };
  '';
}
