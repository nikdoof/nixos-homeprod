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
                  pkgs.socat
                  pkgs.jq
                  pkgs.systemd
                ]
              }"
              set -euo pipefail

              log() { echo "[kea-hook] $*"; }

              KEA_CTRL_SOCKET="/run/kea/kea6-ctrl-socket"
              RADVD_PD_DIR="/run/radvd-pd"

              # Write a radvd prefix fragment for a delegated prefix.
              write_pd_fragment() {
                local prefix="$1" plen="$2"
                local safe frag
                safe=$(printf '%s' "''${prefix}/''${plen}" | tr ':/' '__')
                frag="$RADVD_PD_DIR/''${safe}.conf"
                mkdir -p "$RADVD_PD_DIR"
                printf '  prefix %s/%s {\n    AdvOnLink off;\n    AdvAutonomous on;\n    AdvRouterAddr off;\n  };\n' \
                  "''${prefix}" "''${plen}" > "$frag"
                log "Wrote PD fragment $frag"
              }

              # Remove the radvd prefix fragment for a delegated prefix.
              remove_pd_fragment() {
                local prefix="$1" plen="$2"
                local safe frag
                safe=$(printf '%s' "''${prefix}/''${plen}" | tr ':/' '__')
                frag="$RADVD_PD_DIR/''${safe}.conf"
                rm -f "$frag"
                log "Removed PD fragment $frag"
              }

              # Trigger radvd to re-merge config and reload.
              reload_radvd() {
                systemctl reload radvd.service 2>/dev/null || log "radvd reload failed (service may not be running)"
              }

              # Install routes and radvd fragments for all PD leases held by a
              # given DUID. Used by lease6_renew to recover PD state that Kea
              # 3.0.3 never fires leases6_committed for.
              install_pd_routes_for_duid() {
                local duid="$1" nexthop="$2" iface="$3"
                local response did_pd=0
                response=$(printf '{"command":"lease6-get-by-duid","arguments":{"duid":"%s"}}' "$duid" \
                  | socat - "UNIX-CONNECT:$KEA_CTRL_SOCKET" 2>/dev/null || true)
                local prefix plen
                while IFS=$'\t' read -r prefix plen; do
                  [ -n "$prefix" ] || continue
                  log "Installing PD route $prefix/$plen via $nexthop dev $iface (recovered for duid $duid)"
                  ip -6 route replace "$prefix/$plen" via "$nexthop" dev "$iface"
                  write_pd_fragment "$prefix" "$plen"
                  did_pd=1
                done < <(echo "$response" | jq -r \
                  '.arguments.leases[] | select(.type == "IA_PD") | [.["ip-address"], (.["prefix-len"] | tostring)] | @tsv' \
                  2>/dev/null || true)
                [ "$did_pd" -eq 1 ] && reload_radvd
              }

              # Called after a batch of leases are committed.
              # Adds a route and radvd fragment for each delegated prefix.
              leases6_committed() {
                log "leases6_committed: LEASES6_SIZE=$LEASES6_SIZE"
                local did_pd=0
                for i in $(seq "$LEASES6_SIZE"); do
                  idx=$((i - 1))
                  type="LEASES6_AT''${idx}_TYPE"
                  prefix="LEASES6_AT''${idx}_ADDRESS"
                  plen="LEASES6_AT''${idx}_PREFIX_LEN"

                  log "Lease $idx: type=''${!type} prefix=''${!prefix}/''${!plen}"
                  [ "''${!type}" = "IA_PD" ] || continue

                  log "Adding route ''${!prefix}/''${!plen} via $QUERY6_REMOTE_ADDR dev $QUERY6_IFACE_NAME"
                  ip -6 route replace "''${!prefix}/''${!plen}" via "$QUERY6_REMOTE_ADDR" dev "$QUERY6_IFACE_NAME"
                  write_pd_fragment "''${!prefix}" "''${!plen}"
                  did_pd=1
                done
                [ "$did_pd" -eq 1 ] && reload_radvd
              }

              # Called when a single lease is renewed.
              # Uses singular LEASE6_* vars, not LEASES6_*.
              # For IA_PD: refreshes the route and fragment directly.
              # For IA_NA: queries the control socket for PD leases held by the
              # same client, working around Kea 3.0.3 not firing leases6_committed
              # for PD lease alloc/reuse.
              lease6_renew() {
                log "lease6_renew: type=$LEASE6_TYPE address=$LEASE6_ADDRESS/$LEASE6_PREFIX_LEN client=$QUERY6_REMOTE_ADDR iface=$QUERY6_IFACE_NAME"
                case "$LEASE6_TYPE" in
                  IA_PD)
                    log "Refreshing route $LEASE6_ADDRESS/$LEASE6_PREFIX_LEN via $QUERY6_REMOTE_ADDR dev $QUERY6_IFACE_NAME"
                    ip -6 route replace "$LEASE6_ADDRESS/$LEASE6_PREFIX_LEN" via "$QUERY6_REMOTE_ADDR" dev "$QUERY6_IFACE_NAME"
                    write_pd_fragment "$LEASE6_ADDRESS" "$LEASE6_PREFIX_LEN"
                    reload_radvd
                    ;;
                  IA_NA)
                    install_pd_routes_for_duid "$LEASE6_DUID" "$QUERY6_REMOTE_ADDR" "$QUERY6_IFACE_NAME"
                    ;;
                  *)
                    log "lease6_renew: skipping type $LEASE6_TYPE"
                    ;;
                esac
              }

              # Called when a lease is released or expires.
              # Removes the route and radvd fragment for the delegated prefix.
              lease6_release() {
                log "lease6_release: type=$LEASE6_TYPE address=$LEASE6_ADDRESS/$LEASE6_PREFIX_LEN client=$QUERY6_REMOTE_ADDR iface=$QUERY6_IFACE_NAME"
                [ "$LEASE6_TYPE" = "IA_PD" ] || { log "lease6_release: skipping non-PD lease"; return 0; }
                log "Removing route $LEASE6_ADDRESS/$LEASE6_PREFIX_LEN"
                ip -6 route del "$LEASE6_ADDRESS/$LEASE6_PREFIX_LEN" 2>/dev/null || true
                remove_pd_fragment "$LEASE6_ADDRESS" "$LEASE6_PREFIX_LEN"
                reload_radvd
              }

              unknown_handler() {
                log "Unhandled hook call: $*"
                exit 123
              }

              case "$1" in
                leases6_committed)        leases6_committed ;;
                lease6_renew)             lease6_renew ;;
                lease6_expire | \
                lease6_release)           lease6_release ;;
                *)                        unknown_handler "$@" ;;
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

  # Manually restore radvd PD fragments and routes from current Kea leases.
  # Useful after a reboot before clients have renewed.
  # Usage: kea-restore-pd
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "kea-restore-pd" ''
      set -euo pipefail

      KEA_CTRL_SOCKET="/run/kea/kea6-ctrl-socket"
      RADVD_PD_DIR="/run/radvd-pd"

      # Extract MAC address from a DUID string (colon-separated hex bytes).
      # Supports DUID-LLT (00:01) and DUID-LL (00:03).
      mac_from_duid() {
        local duid="$1"
        local dtype
        dtype=$(echo "$duid" | cut -d: -f1-2)
        case "$dtype" in
          "00:01") echo "$duid" | cut -d: -f9-14 ;;
          "00:03") echo "$duid" | cut -d: -f5-10 ;;
          *) echo "" ;;
        esac
      }

      # Find the link-local address for a MAC in the NDP table.
      nexthop_for_mac() {
        local mac="$1"
        ip -6 neigh show \
          | grep -i "$mac" \
          | awk '/fe80/ {print $1}' \
          | head -1
      }

      echo "Querying Kea control socket for PD leases..."
      response=$(echo '{"command":"lease6-get-all","arguments":{"subnets":[1]}}' \
        | ${pkgs.socat}/bin/socat - "UNIX-CONNECT:$KEA_CTRL_SOCKET")

      mkdir -p "$RADVD_PD_DIR"
      did_pd=0

      while IFS=$'\t' read -r prefix plen duid; do
        [ -n "$prefix" ] || continue

        mac=$(mac_from_duid "$duid")
        if [ -z "$mac" ]; then
          echo "WARN: cannot extract MAC from DUID $duid, skipping $prefix/$plen"
          continue
        fi

        nexthop=$(nexthop_for_mac "$mac")
        if [ -z "$nexthop" ]; then
          echo "WARN: no NDP entry for MAC $mac (duid $duid), skipping route for $prefix/$plen"
        else
          # Find which interface this neighbour is on
          iface=$(ip -6 neigh show | grep -i "$mac" | awk '/fe80/ {print $3}' | head -1)
          echo "Installing route $prefix/$plen via $nexthop dev $iface"
          ip -6 route replace "$prefix/$plen" via "$nexthop" dev "$iface"
        fi

        safe=$(printf '%s' "$prefix/$plen" | tr ':/' '__')
        frag="$RADVD_PD_DIR/$safe.conf"
        ${pkgs.coreutils}/bin/printf '  prefix %s/%s {\n    AdvOnLink off;\n    AdvAutonomous on;\n    AdvRouterAddr off;\n  };\n' \
          "$prefix" "$plen" > "$frag"
        echo "Wrote fragment $frag"
        did_pd=1
      done < <(echo "$response" | ${pkgs.jq}/bin/jq -r \
        '.arguments.leases[] | select(.type == "IA_PD") | [.["ip-address"], (.["prefix-len"] | tostring), .duid] | @tsv')

      if [ "$did_pd" -eq 0 ]; then
        echo "No active PD leases found."
      else
        echo "Reloading radvd..."
        systemctl reload radvd.service
        echo "Done."
      fi
    '')
  ];
}
