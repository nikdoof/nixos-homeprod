{
  dns,
  dns_masters,
  dns_slaves,
  ...
}:
with dns.lib.combinators;
{
  master = true;
  file = dns.lib.toString "int.doofnet.uk" {
    SOA = {
      nameServer = (builtins.head dns_masters);
      adminEmail = "hostmaster@doofnet.uk";
      serial = 2024010100;
    };
    NS = dns_masters;

    TTL = 3600;

    subdomains = {
      # Gateway
      gw = host "10.101.1.1" "2001:8b0:bd9:101::1";

      # Nameservers
      ns1 = host "10.101.1.2" "2001:8b0:bd9:101::2";
      ns2 = host "10.101.1.3" "2001:8b0:bd9:101::3";

      # Infrastructure
      nexus = host "10.101.3.10" "fddd:d00f:dab0:101::10";
      nas-afp = host "10.101.3.11" "fddd:d00f:dab0:101::11";
      jrouter = host "10.101.3.12" "fddd:d00f:dab0:101::12";
      esx-01 = host "10.101.3.15" "fddd:d00f:dab0:101::15";
      nas-03 = host "10.101.3.16" "fddd:d00f:dab0:101::16";

      # Service Hosts
      svc-01 = hosts "10.101.3.20" "fddd:d00f:dab0:101::20";
      svc-02 = hosts "10.101.3.21" "fddd:d00f:dab0:101::21";
      hyp-01 = hosts "10.101.3.22" "fddd:d00f:dab0:101::22";

      # Kubernetes Masters
      prod-master-03 = host "10.101.10.13" "fddd:d00f:dab0:101::10:13";

      # MetalLB endpoints
      unifi.CNAME = [ "svc-01.int.doofnet.uk." ];
    };
  };
  slaves = dns_slaves;
  extraConfig = ''
    allow-update { key doofnet-dhcp-updates; };
  '';
}
