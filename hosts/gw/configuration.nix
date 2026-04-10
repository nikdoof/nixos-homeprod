{ config, pkgs, ... }:

{
  imports = [
    ../../hardware/prodesk-400-g4-sff.nix
    ./hardware-configuration.nix
    ./services
  ];

  # Networking
  networking.hostName = "gw";
  networking.nameservers = [
    "10.101.1.2"
    "2001:8b0:bd9:101::2"
    "10.101.1.3"
    "2001:8b0:bd9:101::3"
  ];
  systemd.network.enable = true;

  # WAN: enp3s0f1 → VLAN 911 → ppp0 (PPPoE to CityFibre ONT)
  systemd.network.netdevs."05-vlan-wan" = {
    netdevConfig = {
      Name = "vlan-wan";
      Kind = "vlan";
    };
    vlanConfig.Id = 911;
  };

  systemd.network.networks = {
    # management interface, if trunk is down
    "10-enp2s0" = {
      matchConfig.Name = "enp2s0";
      addresses = [
        {
          Address = "10.101.3.23/16";
          AddPrefixRoute = false;
        }
        {
          Address = "2001:8b0:bd9:101::3:23/64";
          AddPrefixRoute = false;
        }
      ];
      routes = [
        {
          Destination = "10.101.0.0/16";
          Metric = 2048;
          Scope = "link";
        }
        {
          Destination = "2001:8b0:bd9:101::/64";
          Metric = 2048;
        }
      ];
      # avoid loopback routes from self-advertisements
      networkConfig.IPv6AcceptRA = false;
      linkConfig.RequiredForOnline = "no";
    };

    # Internal VLANs trunk
    "10-enp3s0f0" = {
      matchConfig.Name = "enp3s0f0";
      linkConfig.RequiredForOnline = "no";
      networkConfig.VLAN = [
        config.systemd.network.netdevs."10-vlan-private".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-public".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-lab".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-ha".netdevConfig.Name
        config.systemd.network.netdevs."10-vlan-hosted".netdevConfig.Name
      ];
    };

    # VLAN 101 - Private
    "10-vlan-private" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-private".netdevConfig.Name;
      networkConfig.Address = [
        "10.101.1.1/16"
        "2001:8b0:bd9:101::1/64"
      ];
    };

    # VLAN 102 - Public
    "10-vlan-public" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-public".netdevConfig.Name;
      networkConfig.Address = [
        "10.102.1.1/16"
        "2001:8b0:bd9:102::1/64"
      ];
    };

    # VLAN 104 - Lab
    "10-vlan-lab" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-lab".netdevConfig.Name;
      networkConfig.Address = [
        "10.104.1.1/16"
        "2001:8b0:bd9:104::1/64"
      ];
    };

    # VLAN 105 - HA/IoT
    "10-vlan-ha" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-ha".netdevConfig.Name;
      networkConfig.Address = [ "10.105.1.1/16" ];
    };

    # Hosted VLAN uses a publicly routable /29 block (not NATed)
    "10-vlan-hosted" = {
      matchConfig.Name = config.systemd.network.netdevs."10-vlan-hosted".netdevConfig.Name;
      networkConfig.Address = [
        "217.169.25.9/29"
        "2001:8b0:bd9:106::1/64"
      ];
    };

    # WAN intf
    "05-enp3s0f1" = {
      matchConfig.Name = "enp3s0f1";
      linkConfig = {
        MTUBytes = 1508;
        RequiredForOnline = "no";
      };
      networkConfig.VLAN = [ "vlan-wan" ];
    };

    "05-vlan-wan" = {
      matchConfig.Name = "vlan-wan";
      linkConfig.RequiredForOnline = "no";
      networkConfig.LinkLocalAddressing = "no";
      linkConfig = {
        MTUBytes = 1508;
      };
    };

    # PPP to AAISP
    "30-ppp0" = {
      matchConfig.Name = "ppp0";
      networkConfig = {
        DHCP = "ipv6";
        IPv6AcceptRA = true;
      };
      dhcpV6Config = {
        UseDNS = "no";
        WithoutRA = "solicit";
      };
      ipv6AcceptRAConfig = {
        UseDNS = "no";
        DHCPv6Client = "always";
      };
      linkConfig.RequiredForOnline = "no";
    };
  };

  boot.kernel.sysctl = {
    # IP forwarding — required for router operation
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv6.conf.all.forwarding" = true;

    # Reverse-path filtering — drop packets with spoofed source IPs (CIS 3.2.7)
    # ppp0 uses loose mode (2) to handle any PPPoE/ISP asymmetric routing
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.ppp0.rp_filter" = 2;

    # Disable IP source routing (CIS 3.2.1)
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;

    # Reject ICMP redirects — router has no need to be redirected (CIS 3.2.2)
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;

    # Do not send ICMP redirects on internal interfaces (CIS 3.1.2)
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;

    # Log martian packets — spoofed or impossible source addresses (CIS 3.2.4)
    "net.ipv4.conf.all.log_martians" = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # Ignore broadcast pings — Smurf amplification protection (CIS 3.2.5)
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;

    # Ignore bogus ICMP error responses (CIS 3.2.6)
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # SYN flood protection (CIS 3.2.8)
    "net.ipv4.tcp_syncookies" = 1;

    # TIME_WAIT assassination protection (RFC 1337)
    "net.ipv4.tcp_rfc1337" = 1;

    # Kernel hardening — restrict dmesg and kernel pointer exposure
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;

    # Full ASLR (CIS 1.5.3)
    "kernel.randomize_va_space" = 2;

    # Restrict ptrace to parent processes only
    "kernel.yama.ptrace_scope" = 1;

    # Filesystem hardening — prevent hardlink/symlink privilege escalation
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;

    # No core dumps for SUID programs (CIS 1.5.1)
    "fs.suid_dumpable" = 0;

    # Disable unprivileged BPF and harden JIT against info leaks
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;

    # TCP buffer sizing for 1 Gbps
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.core.netdev_max_backlog" = 5000;

    # Enable MTU probing — handles ICMP-blackhole scenarios on PPPoE
    "net.ipv4.tcp_mtu_probing" = 1;
  };

  environment.systemPackages = with pkgs; [
    speedtest-cli
    bmon
    iftop
    iperf
  ];

  doofnet.network.vlans = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.11"; # Did you read the comment?

}
