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

    subdomains = {
      # Gateway
      gw = host "10.101.1.1" "2001:8b0:bd9:101::1";

      # Nameservers
      ns-01 = host "10.101.1.2" "2001:8b0:bd9:101::2";
      ns-02 = host "10.101.1.3" "2001:8b0:bd9:101::3";

      # Infrastructure
      nas-afp = host "10.101.3.11" "fddd:d00f:dab0:101::11";
      jrouter = host "10.101.3.12" "fddd:d00f:dab0:101::12";
      esx-01 = host "10.101.3.15" "fddd:d00f:dab0:101::15";
      nas-03 = host "10.101.3.16" "fddd:d00f:dab0:101::16";

      # Service Hosts
      svc-01 = host "10.101.3.20" "fddd:d00f:dab0:101::20";
      svc-02 = host "10.101.3.21" "fddd:d00f:dab0:101::21";
      hyp-01 = host "10.101.3.22" "fddd:d00f:dab0:101::22";

      # Kubernetes Masters
      prod-master-03 = host "10.101.10.13" "fddd:d00f:dab0:101::10:13";

      # MetalLB endpoints
      unifi.CNAME = [ "svc-01.int.doofnet.uk." ];
    };
  };
  extraConfig = ''
    allow-update { doofnet-dhcp-updates; };
  '';
}
