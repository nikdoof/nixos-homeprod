{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "mfg.cobaltmicro.com" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2024010100;
    };
    NS = dns_masters;

    TTL = 3600;

    subdomains = {
      # DNS for netboot of Cobalt Raq3
      tester.A = [ "10.101.3.104" ];
    };
  };
  slaves = dns_slaves;
}
