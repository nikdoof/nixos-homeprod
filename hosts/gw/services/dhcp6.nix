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
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_lease_cmds.so";
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
      ddns-replace-client-name = "never";

      subnet6 = [
        {
          # VLAN 101 - Private
          id = 1;
          subnet = "2001:8b0:bd9:101::/64";
          interface = "vlan-private";
          ddns-qualifying-suffix = "int.doofnet.uk";
          pools = [ { pool = "2001:8b0:bd9:101::2000 - 2001:8b0:bd9:101::2fff"; } ];
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
