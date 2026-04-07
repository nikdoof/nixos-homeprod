{ pkgs, ... }:
{
  services.radvd = {
    enable = true;
    # Static interfaces only — vlan-private is handled dynamically
    config = ''
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

      # VLAN 106 - Hosted
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

  systemd.services.radvd-pd-init = {
    description = "Initialise radvd dynamic PD config";
    wantedBy = [ "radvd.service" ];
    before = [ "radvd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /run/radvd-pd-prefixes
      # Write a valid vlan-private block with no PD prefixes yet
      cat > /run/radvd-dynamic.conf <<'EOF'
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
      EOF
    '';
  };

  # Override radvd's ExecStart to concatenate static + dynamic configs
  systemd.services.radvd = {
    after = [ "radvd-pd-init.service" ];
    requires = [ "radvd-pd-init.service" ];
    serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "radvd-merge-conf" ''
        cat /etc/radvd.conf /run/radvd-dynamic.conf > /run/radvd-merged.conf
      '';
      ExecStart = pkgs.lib.mkForce "${pkgs.radvd}/sbin/radvd -n -C /run/radvd-merged.conf";
      ExecReload = pkgs.writeShellScript "radvd-reload" ''
        cat /etc/radvd.conf /run/radvd-dynamic.conf > /run/radvd-merged.conf
        kill -HUP $MAINPID
      '';
    };
  };
}
