{ pkgs, lib, ... }:
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
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_lease_cmds.so";
        }
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_run_script.so";
          parameters = {
            name = pkgs.writeShellScript "kea-run-hooks" ''
              export PATH="${
                lib.strings.makeBinPath [
                  pkgs.coreutils
                  pkgs.iproute2
                ]
              }"
              set -euo pipefail

              log() { echo "[kea-hook] $*"; }

              # Called after a batch of leases are committed.
              # Adds a route for each delegated prefix (IA_PD, type=2).
              leases6_committed() {
                for i in $(seq "$LEASES6_SIZE"); do
                  idx=$((i - 1))
                  type="LEASES6_AT''${idx}_TYPE"
                  prefix="LEASES6_AT''${idx}_ADDRESS"
                  plen="LEASES6_AT''${idx}_PREFIX_LEN"

                  [ "''${!type}" = "2" ] || continue

                  log "Adding route ''${!prefix}/''${!plen} via $QUERY6_REMOTE_ADDR dev $QUERY6_IFACE_NAME"
                  ip -6 route replace "''${!prefix}/''${!plen}" via "$QUERY6_REMOTE_ADDR" dev "$QUERY6_IFACE_NAME"
                done
              }

              # Called when a lease is released or expires.
              # Removes the route for the delegated prefix.
              lease6_release() {
                log "Removing route $LEASE6_ADDRESS/$LEASE6_PREFIX_LEN"
                ip -6 route del "$LEASE6_ADDRESS/$LEASE6_PREFIX_LEN"
              }

              unknown_handler() {
                log "Unhandled hook call: $*"
                exit 123
              }

              case "$1" in
                lease6_renew | leases6_committed)       leases6_committed ;;
                lease6_expire | \
                lease6_release)          lease6_release ;;
                *)                       unknown_handler "$@" ;;
              esac
            '';
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
          rapid-commit = true;
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

  systemd.services.kea-dhcp6-server.serviceConfig = {
    AmbientCapabilities = [ "CAP_NET_ADMIN" ];
    CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
  };
}
