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
      serial = 2026040101;
      refresh = 3600;
      retry = 900;
      expire = 604800;
      minimum = 300;
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
      nas-01 = host "10.101.3.16" "fddd:d00f:dab0:101::16";
      nas-03 = host "10.101.3.16" "fddd:d00f:dab0:101::16";

      # Service Hosts
      svc-01 = host "10.101.3.20" "fddd:d00f:dab0:101::20";
      svc-02 = host "10.101.3.21" "fddd:d00f:dab0:101::21";
      hyp-01 = host "10.101.3.22" "fddd:d00f:dab0:101::22";
      gw-mgmt = host "10.101.3.23" "fddd:d00f:dab0:101::3:23";

      # VMs
      afp-01 = host "10.101.3.30" "fddd:d00f:dab0:101::3:30";
      grf-01 = host "10.101.3.31" "fddd:d00f:dab0:101::3:31";

      # Service endpoints
      unifi.CNAME = [ "svc-01.int.doofnet.uk." ];
    };
  };
  extraConfig = ''
    update-policy {
      # Protect all statically-defined records
      deny doofnet-dhcp-updates name gw.int.doofnet.uk.      ANY;
      deny doofnet-dhcp-updates name ns-01.int.doofnet.uk.   ANY;
      deny doofnet-dhcp-updates name ns-02.int.doofnet.uk.   ANY;
      deny doofnet-dhcp-updates name nas-01.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name nas-03.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name svc-01.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name svc-02.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name hyp-01.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name gw-mgmt.int.doofnet.uk. ANY;
      deny doofnet-dhcp-updates name afp-01.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name grf-01.int.doofnet.uk.  ANY;
      deny doofnet-dhcp-updates name unifi.int.doofnet.uk.   ANY;
      # Allow DDNS updates for all other names in the zone (DHCP clients)
      grant doofnet-dhcp-updates zonesub ANY;
    };
  '';
}
