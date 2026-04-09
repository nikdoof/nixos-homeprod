{ pkgs, ... }:
let
  staticConf = pkgs.writeText "radvd-static.conf" ''
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

  # Merges staticConf with any PD prefix fragments from /run/radvd-pd/*.conf,
  # injecting them into the vlan-private interface block before its closing };
  mergeScript = pkgs.writeShellScript "radvd-merge-conf" ''
    set -euo pipefail

    PD_DIR=/run/radvd-pd
    OUT=/run/radvd.conf
    TMP=$(${pkgs.coreutils}/bin/mktemp /run/radvd.conf.XXXXXX)

    pd_content=""
    for f in "$PD_DIR"/*.conf; do
      [ -f "$f" ] || break
      pd_content="$pd_content$(${pkgs.coreutils}/bin/cat "$f")"
    done

    if [ -z "$pd_content" ]; then
      ${pkgs.coreutils}/bin/cp "${staticConf}" "$TMP"
    else
      ${pkgs.gawk}/bin/awk \
        -v pd="$pd_content" \
        '
        /^[[:space:]]*interface[[:space:]]+vlan-private[[:space:]]*\{/ { in_block=1 }
        in_block && /^\};/ && !injected {
          print pd
          injected=1
          in_block=0
        }
        { print }
        ' "${staticConf}" > "$TMP"
    fi

    ${pkgs.coreutils}/bin/mv "$TMP" "$OUT"
  '';

  # Re-merges config then signals the running radvd to re-read it.
  # $MAINPID is substituted by systemd in ExecReload context.
  reloadScript = pkgs.writeShellScript "radvd-reload" ''
    ${mergeScript}
    kill -HUP "$MAINPID"
  '';
in
{
  services.radvd.enable = false;

  # The NixOS radvd module normally creates these; do it explicitly since
  # we disabled the module.
  users.users.radvd = {
    isSystemUser = true;
    group = "radvd";
    description = "Router Advertisement Daemon User";
  };
  users.groups.radvd = { };

  systemd.services.radvd = {
    description = "IPv6 Router Advertisement Daemon (dynamic PD)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network.target"
      "kea-dhcp6-server.service"
    ];
    serviceConfig = {
      Type = "simple";
      # Creates /run/radvd-pd/ before ExecStartPre runs.
      RuntimeDirectory = "radvd-pd";
      RuntimeDirectoryMode = "0777";
      ExecStartPre = mergeScript;
      ExecStart = "${pkgs.radvd}/bin/radvd -n -u radvd -C /run/radvd.conf";
      ExecReload = reloadScript;
      Restart = "on-failure";
    };
  };
}
