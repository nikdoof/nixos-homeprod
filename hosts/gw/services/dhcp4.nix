_: {
  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = [
        "vlan-private"
        "vlan-public"
        "vlan-lab"
        "vlan-ha"
      ];

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };

      "control-socket" = {
        socket-type = "unix";
        socket-name = "/run/kea/kea4-ctrl-socket";
      };

      valid-lifetime = 86400;

      # Send DNS updates to kea-dhcp-ddns; server handles updates, not client.
      dhcp-ddns = {
        enable-updates = true;
        server-ip = "127.0.0.1";
        server-port = 53001;
      };
      ddns-send-updates = true;
      ddns-override-client-update = true;
      ddns-replace-client-name = "when-not-present";

      # PXE boot: serve different files for BIOS vs UEFI clients based on
      # PXE client architecture option (93). next-server is set per-subnet.
      client-classes = [
        {
          name = "PXE-BIOS";
          test = "option[93].hex == 0x0000";
          boot-file-name = "undionly.kpxe";
        }
        {
          name = "PXE-EFI";
          test = "option[93].hex == 0x0007 or option[93].hex == 0x0009";
          boot-file-name = "ipxe.efi";
        }
      ];

      subnet4 = [
        {
          # VLAN 101 - Private
          id = 1;
          subnet = "10.101.0.0/16";
          interface = "vlan-private";
          next-server = "10.101.3.21";
          ddns-qualifying-suffix = "int.doofnet.uk";
          pools = [ { pool = "10.101.2.1 - 10.101.2.254"; } ];
          option-data = [
            {
              name = "routers";
              data = "10.101.1.1";
            }
            {
              name = "domain-name";
              data = "int.doofnet.uk";
            }
            {
              name = "domain-search";
              data = "int.doofnet.uk, lab.doofnet.uk, dmz.doofnet.uk, doofnet.uk";
            }
            {
              name = "domain-name-servers";
              data = "10.101.1.2, 10.101.1.3";
            }
            {
              name = "ntp-servers";
              data = "10.101.1.1, 217.169.20.20, 217.169.20.21";
            }
          ];
          reservations = [
            {
              hw-address = "10:62:e5:14:61:84";
              ip-address = "10.101.3.20";
              hostname = "svc-01";
            }
            {
              hw-address = "f4:39:09:3a:4d:a4";
              ip-address = "10.101.3.21";
              hostname = "svc-02";
            }
            {
              hw-address = "10:e7:c6:03:97:18";
              ip-address = "10.101.3.22";
              hostname = "hyp-01";
            }
          ];
        }
        {
          # VLAN 102 - Public
          id = 2;
          subnet = "10.102.0.0/16";
          interface = "vlan-public";
          ddns-qualifying-suffix = "pub.doofnet.uk";
          pools = [ { pool = "10.102.2.1 - 10.102.2.254"; } ];
          option-data = [
            {
              name = "routers";
              data = "10.102.1.1";
            }
            {
              name = "domain-name";
              data = "pub.doofnet.uk";
            }
            {
              name = "domain-search";
              data = "pub.doofnet.uk, dmz.doofnet.uk";
            }
            {
              name = "domain-name-servers";
              data = "10.101.1.2, 10.101.1.3";
            }
            {
              name = "ntp-servers";
              data = "10.102.1.1, 217.169.20.20, 217.169.20.21";
            }
          ];
        }
        {
          # VLAN 104 - Lab
          id = 3;
          subnet = "10.104.0.0/16";
          interface = "vlan-lab";
          next-server = "10.101.3.102";
          ddns-qualifying-suffix = "lab.doofnet.uk";
          pools = [ { pool = "10.104.2.1 - 10.104.2.254"; } ];
          option-data = [
            {
              name = "routers";
              data = "10.104.1.1";
            }
            {
              name = "domain-name";
              data = "lab.doofnet.uk";
            }
            {
              name = "domain-search";
              data = "lab.doofnet.uk, int.doofnet.uk, dmz.doofnet.uk, doofnet.uk";
            }
            {
              name = "domain-name-servers";
              data = "10.101.1.2, 10.101.1.3";
            }
            {
              name = "ntp-servers";
              data = "10.101.1.1, 217.169.20.20, 217.169.20.21";
            }
          ];
        }
        {
          # VLAN 105 - HA
          id = 4;
          subnet = "10.105.0.0/16";
          interface = "vlan-ha";
          ddns-qualifying-suffix = "ha.doofnet.uk";
          pools = [ { pool = "10.105.2.1 - 10.105.2.254"; } ];
          option-data = [
            {
              name = "routers";
              data = "10.105.1.1";
            }
            {
              name = "domain-name";
              data = "ha.doofnet.uk";
            }
            {
              name = "domain-name-servers";
              data = "10.101.1.2, 10.101.1.3";
            }
            {
              name = "ntp-servers";
              data = "10.101.1.1, 217.169.20.20, 217.169.20.21";
            }
          ];
        }
      ];

    };
  };
}
