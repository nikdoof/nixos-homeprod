{ pkgs, ... }:
let
  pdHookScript = pkgs.writeShellScript "kea-pd-hook" ''
    PD_DIR="/run/radvd-pd-prefixes"
    RADVD_DYNAMIC_CONF="/run/radvd-dynamic.conf"
    NEXTHOP_DIR="/var/lib/kea/pd-nexthops"

    write_radvd_dynamic_conf() {
      {
        echo "interface vlan-private {"
        echo "  AdvSendAdvert on;"
        echo "  AdvManagedFlag on;"
        echo "  AdvOtherConfigFlag on;"
        echo "  AdvDefaultPreference high;"
        echo ""
        echo "  prefix 2001:8b0:bd9:101::/64 {"
        echo "    AdvOnLink on;"
        echo "    AdvAutonomous off;"
        echo "    AdvRouterAddr on;"
        echo "  };"
        echo ""
        echo "  prefix fddd:d00f:dab0:101::/64 {"
        echo "    AdvOnLink on;"
        echo "    AdvAutonomous on;"
        echo "  };"
        echo ""
        for f in "''${PD_DIR}"/*.conf; do
          [ -f "''${f}" ] && cat "''${f}"
        done
        echo ""
        echo "  RDNSS 2001:8b0:bd9:101::2 2001:8b0:bd9:101::3 {"
        echo "    AdvRDNSSLifetime 3600;"
        echo "  };"
        echo ""
        echo "  DNSSL int.doofnet.uk {"
        echo "    AdvDNSSLLifetime 3600;"
        echo "  };"
        echo "};"
      } > "''${RADVD_DYNAMIC_CONF}"
    }

    case "$1" in
      hook_load)
        # On Kea startup, reinstall routes and radvd from persisted nexthop info
        mkdir -p "''${PD_DIR}"
        CHANGED=0
        for f in "''${NEXTHOP_DIR}"/*.nexthop; do
          [ -f "''${f}" ] || continue
          read -r PREFIX NEXTHOP IFACE < "''${f}"
          [ -n "''${PREFIX}" ] && [ -n "''${NEXTHOP}" ] && [ -n "''${IFACE}" ] || continue

          SAFE_PREFIX=$(echo "''${PREFIX}" | tr ':/' '-' | tr -s '-')
          ${pkgs.iproute2}/bin/ip -6 route replace "''${PREFIX}" \
            via "''${NEXTHOP}" dev "''${IFACE}" metric 1024 || true

          cat > "''${PD_DIR}/''${SAFE_PREFIX}.conf" <<EOF
      prefix ''${PREFIX} {
          AdvOnLink off;
          AdvAutonomous off;
          AdvRouterAddr off;
      };
    EOF
          CHANGED=1
        done
        if [ "''${CHANGED}" = "1" ]; then
          write_radvd_dynamic_conf
          ${pkgs.systemd}/bin/systemctl reload radvd.service 2>/dev/null || true
        fi
        ;;

      leases6_committed)
        NEXTHOP="''${QUERY6_REMOTE_ADDR}"
        IFACE="''${QUERY6_IFACE_NAME}"
        CHANGED=0

        i=0
        while [ "''${i}" -lt "''${LEASES6_SIZE:-0}" ]; do
          eval "TYPE=\$LEASES6_AT''${i}_TYPE"
          [ "''${TYPE}" = "IA_PD" ] || { i=$((i+1)); continue; }

          eval "ADDR=\$LEASES6_AT''${i}_ADDRESS"
          eval "PLEN=\$LEASES6_AT''${i}_PREFIX_LEN"
          PREFIX="''${ADDR}/''${PLEN}"
          SAFE_PREFIX=$(echo "''${PREFIX}" | tr ':/' '-' | tr -s '-')

          ${pkgs.iproute2}/bin/ip -6 route replace "''${PREFIX}" \
            via "''${NEXTHOP}" \
            dev "''${IFACE}" \
            metric 1024

          mkdir -p "''${PD_DIR}" "''${NEXTHOP_DIR}"
          echo "''${PREFIX} ''${NEXTHOP} ''${IFACE}" > "''${NEXTHOP_DIR}/''${SAFE_PREFIX}.nexthop"
          cat > "''${PD_DIR}/''${SAFE_PREFIX}.conf" <<EOF
      prefix ''${PREFIX} {
          AdvOnLink off;
          AdvAutonomous off;
          AdvRouterAddr off;
      };
    EOF
          CHANGED=1
          i=$((i+1))
        done

        i=0
        while [ "''${i}" -lt "''${DELETED_LEASES6_SIZE:-0}" ]; do
          eval "TYPE=\$DELETED_LEASES6_AT''${i}_TYPE"
          [ "''${TYPE}" = "IA_PD" ] || { i=$((i+1)); continue; }

          eval "ADDR=\$DELETED_LEASES6_AT''${i}_ADDRESS"
          eval "PLEN=\$DELETED_LEASES6_AT''${i}_PREFIX_LEN"
          PREFIX="''${ADDR}/''${PLEN}"
          SAFE_PREFIX=$(echo "''${PREFIX}" | tr ':/' '-' | tr -s '-')

          ${pkgs.iproute2}/bin/ip -6 route del "''${PREFIX}" 2>/dev/null || true
          rm -f "''${PD_DIR}/''${SAFE_PREFIX}.conf"
          rm -f "''${NEXTHOP_DIR}/''${SAFE_PREFIX}.nexthop"
          CHANGED=1
          i=$((i+1))
        done

        if [ "''${CHANGED}" = "1" ]; then
          write_radvd_dynamic_conf
          ${pkgs.systemd}/bin/systemctl reload radvd.service
        fi
        ;;
    esac
  '';
in
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
            name = pdHookScript;
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
}
