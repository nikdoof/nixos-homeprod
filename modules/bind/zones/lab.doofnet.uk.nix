{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "lab.doofnet.uk" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2024010100;
    };
    NS = dns_masters;

    TTL = 3600;

    subdomains = {
      # Gateway
      gw = host "10.104.1.1" "2001:8b0:bd9:104::1";
    };
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-update { key doofnet-dhcp-updates; };
  '';
}
