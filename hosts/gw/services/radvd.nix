_: {
  services.radvd = {
    enable = true;
    config = ''
      # VLAN 101 - Private
      interface vlan-private {
        AdvSendAdvert on;
        AdvManagedFlag on;
        AdvOtherConfigFlag on;
        AdvDefaultPreference high;

        prefix 2001:8b0:bd9:101::/64 {
          AdvOnLink on;
          AdvAutonomous off;
          AdvRouterAddr on;
        };

        prefix fddd:d00f:dab0:101::/64 {
          AdvOnLink on;
          AdvAutonomous on;
        };

        RDNSS 2001:8b0:bd9:101::2 2001:8b0:bd9:101::3 {
          AdvRDNSSLifetime 3600;
        };

        DNSSL int.doofnet.uk {
          AdvDNSSLLifetime 3600;
        };
      };

      # VLAN 102 - Public
      interface vlan-public {
        AdvSendAdvert on;
        AdvManagedFlag on;
        AdvOtherConfigFlag on;
        AdvDefaultPreference medium;

        prefix 2001:8b0:bd9:102::/64 {
          AdvOnLink on;
          AdvAutonomous off;
          AdvRouterAddr on;
        };

        RDNSS 2001:8b0:bd9:101::2 2001:8b0:bd9:101::3 {
          AdvRDNSSLifetime 3600;
        };

        DNSSL pub.doofnet.uk {
          AdvDNSSLLifetime 3600;
        };
      };

      # VLAN 104 - Lab
      interface vlan-lab {
        AdvSendAdvert on;
        AdvManagedFlag on;
        AdvOtherConfigFlag on;
        AdvDefaultPreference medium;

        prefix 2001:8b0:bd9:104::/64 {
          AdvOnLink on;
          AdvAutonomous off;
          AdvRouterAddr on;
        };

        prefix fddd:d00f:dab0:104::/64 {
          AdvOnLink on;
          AdvAutonomous on;
        };

        RDNSS 2001:8b0:bd9:101::2 2001:8b0:bd9:101::3 {
          AdvRDNSSLifetime 3600;
        };

        DNSSL lab.doofnet.uk {
          AdvDNSSLLifetime 3600;
        };
      };

      # VLAN 106 - Hosted (SLAAC only, no DHCPv6)
      interface vlan-hosted {
        AdvSendAdvert on;
        AdvManagedFlag off;
        AdvOtherConfigFlag off;
        AdvDefaultPreference medium;

        prefix 2001:8b0:bd9:106::/64 {
          AdvOnLink on;
          AdvAutonomous on;
          AdvRouterAddr on;
        };
      };
    '';
  };
}
