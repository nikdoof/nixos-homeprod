{ pkgs, ... }:
{
  services.kea.dhcp6 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = [
        "vlan-private"
        "vlan-public"
        "vlan-lab"
      ];

      "control-socket" = {
        socket-type = "unix";
        socket-name = "/run/kea/kea6-ctrl-socket";
      };

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp6.leases";
        lfc-interval = 1800;
        max-row-errors = 100;
      };

      hooks-libraries = [
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_run_script.so";
          parameters = {
            name = "/etc/kea/pd-hook.sh";
            sync = false;
          };
        }
      ];

      # Send DNS updates to kea-dhcp-ddns; server handles updates, not client.
      dhcp-ddns = {
        enable-updates = true;
        server-ip = "127.0.0.1";
        server-port = 53001;
      };
      ddns-send-updates = true;
      ddns-override-client-update = true;
      ddns-replace-client-name = "when-not-present";

      subnet6 = [
        {
          # VLAN 101 - Private
          id = 1;
          subnet = "2001:8b0:bd9:101::/64";
          interface = "vlan-private";
          ddns-qualifying-suffix = "int.doofnet.uk";
          pools = [ { pool = "2001:8b0:bd9:101::2000 - 2001:8b0:bd9:101::2fff"; } ];
          # Prefix delegation: hand out /64s from 2001:8b0:bd9:200::/56
          pd-pools = [
            {
              prefix = "2001:8b0:bd9:200::";
              prefix-len = 56;
              delegated-len = 64;
            }
          ];
          option-data = [
            {
              name = "dns-servers";
              data = "2001:8b0:bd9:101::2, 2001:8b0:bd9:101::3";
            }
            {
              name = "domain-search";
              data = "int.doofnet.uk, lab.doofnet.uk";
            }
            {
              name = "sntp-servers";
              data = "2001:8b0:bd9:101::1";
            }
          ];
        }
        {
          # VLAN 102 - Public
          id = 2;
          subnet = "2001:8b0:bd9:102::/64";
          interface = "vlan-public";
          ddns-qualifying-suffix = "pub.doofnet.uk";
          pools = [ { pool = "2001:8b0:bd9:102::2000 - 2001:8b0:bd9:102::2fff"; } ];
          option-data = [
            {
              name = "dns-servers";
              data = "2001:8b0:bd9:101::2, 2001:8b0:bd9:101::3";
            }
            {
              name = "domain-search";
              data = "pub.doofnet.uk";
            }
            {
              name = "sntp-servers";
              data = "2001:8b0:bd9:102::1";
            }
          ];
        }
        {
          # VLAN 104 - Lab
          id = 3;
          subnet = "2001:8b0:bd9:104::/64";
          interface = "vlan-lab";
          ddns-qualifying-suffix = "lab.doofnet.uk";
          pools = [ { pool = "2001:8b0:bd9:104::2000 - 2001:8b0:bd9:104::2fff"; } ];
          option-data = [
            {
              name = "dns-servers";
              data = "2001:8b0:bd9:101::2, 2001:8b0:bd9:101::3";
            }
            {
              name = "domain-search";
              data = "lab.doofnet.uk, int.doofnet.uk";
            }
            {
              name = "sntp-servers";
              data = "2001:8b0:bd9:104::1";
            }
          ];
        }
      ];
    };
  };

  environment.etc."kea/pd-hook.sh" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      # Called by Kea run_script hook for all lease6 events

      PD_DIR="/run/radvd-pd-prefixes"
      PD_CONF="/run/radvd-pd-prefix.conf"

      case "$1" in
        lease6_add|lease6_update)
          [ "$LEASE6_TYPE" = "IA_PD" ] || exit 0

          PREFIX="''${LEASE6_ADDRESS}/''${LEASE6_PREFIXLEN}"
          NEXTHOP="''${QUERY6_REMOTE_ADDR}"
          IFACE="''${QUERY6_IFACE_NAME}"

          # Install/update route for delegated prefix via client's link-local
          ${pkgs.iproute2}/bin/ip -6 route replace "''${PREFIX}" \
            via "''${NEXTHOP}" \
            dev "''${IFACE}" \
            metric 1024

          # Write a per-prefix file, named by sanitised prefix
          # e.g. 2001:8b0:bd9:206::/64 -> 20018b0bd9206--64
          SAFE_PREFIX=$(echo "''${PREFIX}" | tr ':/' '-' | tr -s '-')
          mkdir -p "''${PD_DIR}"
          cat > "''${PD_DIR}/''${SAFE_PREFIX}.conf" <<EOF
      prefix ''${PREFIX} {
          AdvOnLink off;
          AdvAutonomous off;
          AdvRouterAddr off;
      };
      EOF

          # Rebuild the combined conf from all per-prefix files
          cat ''${PD_DIR}/*.conf > "''${PD_CONF}"

          # Signal radvd to reload
          ${pkgs.systemd}/bin/systemctl reload radvd.service
          ;;

        lease6_delete)
          [ "$LEASE6_TYPE" = "IA_PD" ] || exit 0

          PREFIX="''${LEASE6_ADDRESS}/''${LEASE6_PREFIXLEN}"

          # Remove route
          ${pkgs.iproute2}/bin/ip -6 route del "''${PREFIX}" 2>/dev/null || true

          # Remove the per-prefix file
          SAFE_PREFIX=$(echo "''${PREFIX}" | tr ':/' '-' | tr -s '-')
          rm -f "''${PD_DIR}/''${SAFE_PREFIX}.conf"

          # Rebuild combined conf, or write empty placeholder if none left
          if ls "''${PD_DIR}"/*.conf 2>/dev/null | grep -q .; then
            cat ''${PD_DIR}/*.conf > "''${PD_CONF}"
          else
            echo "# No PD prefixes currently assigned" > "''${PD_CONF}"
          fi

          ${pkgs.systemd}/bin/systemctl reload radvd.service
          ;;
      esac
    '';
  };

  systemd.services.radvd-pd-init = {
    description = "Initialise radvd PD prefix state directory";
    wantedBy = [ "radvd.service" ];
    before = [ "radvd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /run/radvd-pd-prefixes
      if [ ! -f /run/radvd-pd-prefix.conf ]; then
        echo "# No PD prefixes currently assigned" > /run/radvd-pd-prefix.conf
      fi
    '';
  };
}
