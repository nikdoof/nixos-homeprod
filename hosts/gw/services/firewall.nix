_: {
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet filter {

      # Internal IPv4 address space (RFC1918 + hosted public /29)
      set local4 {
        type ipv4_addr
        flags interval
        elements = { 10.0.0.0/8, 217.169.25.8/29 }
      }

      # Internal IPv6 address space (assigned /48 + ULA fc00::/7)
      set local6 {
        type ipv6_addr
        flags interval
        elements = { 2001:8b0:bd9::/48, fc00::/7 }
      }

      # Hurricane Electric secondary nameservers (zone transfer / NOTIFY)
      set he_dns4 {
        type ipv4_addr
        elements = { 216.218.133.2 }
      }

      set he_dns6 {
        type ipv6_addr
        elements = { 2001:470:600::2 }
      }

      # Internal recursive resolvers (ns1 + ns2 on vlan-private)
      set ns4 {
        type ipv4_addr
        elements = { 10.101.1.2, 10.101.1.3 }
      }

      set ns6 {
        type ipv6_addr
        elements = { 2001:8b0:bd9:101::2, 2001:8b0:bd9:101::3 }
      }

      # Ports the hosted VLAN is permitted to use outbound
      set hosted_out_tcp {
        type inet_service
        elements = { 22, 23, 25, 53, 70, 79, 80, 123, 443, 1965 }
      }

      set hosted_out_udp {
        type inet_service
        elements = { 53, 123 }
      }

      chain input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop
        iif lo accept

        # Rules for accept on gw interfaces

        # ICMPv4
        ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } limit rate 10/second accept

        # ICMPv6
        ip6 nexthdr icmpv6 accept

        # DHCPv4 server
        iifname { "vlan-private", "vlan-public", "vlan-lab", "vlan-ha", "vlan-hosted" } udp dport 67 accept

        # DHCPv6 server
        iifname { "vlan-private", "vlan-public", "vlan-lab", "vlan-hosted" } udp dport 547 accept

        # DHCPv6 client on WAN
        # track it; allow the unicast Advertise/Reply back on port 546 explicitly
        iifname "ppp0" udp dport 546 accept

        # DNS - HE secondary nameservers (zone transfer / NOTIFY)
        ip  saddr @he_dns4 tcp dport 53 accept
        ip6 saddr @he_dns6 tcp dport 53 accept

        # DNS - hosted VLAN relay (unbound forwards to ns-01/ns-02)
        iifname "vlan-hosted" udp dport 53 accept
        iifname "vlan-hosted" tcp dport 53 accept

        # NTP
        ip  saddr @local4 udp dport 123 accept
        ip6 saddr @local6 udp dport 123 accept

        # SSH
        iifname { "vlan-private", "enp2s0", "tailscale0" } tcp dport 22 accept

        # mDNS
        iifname { "vlan-private", "vlan-lab", "vlan-ha" } udp dport 5353 accept

        # UPnP SSDP
        iifname { "vlan-private", "vlan-public" } udp dport 1900 accept

        # NAT-PMP / PCP
        iifname { "vlan-private", "vlan-public" } udp dport 5351 accept
      }

      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop

        # ICMPv6
        ip6 nexthdr icmpv6 accept

        # Allow DNATs
        ct status dnat accept

        # DNS
        iifname { "vlan-public", "vlan-hosted", "vlan-ha" } ip  daddr @ns4 udp dport 53 accept
        iifname { "vlan-public", "vlan-hosted", "vlan-ha" } ip  daddr @ns4 tcp dport 53 accept
        iifname { "vlan-public", "vlan-hosted" }            ip6 daddr @ns6 udp dport 53 accept
        iifname { "vlan-public", "vlan-hosted" }            ip6 daddr @ns6 tcp dport 53 accept

        # mDNS (Bonjour/Avahi) between private, lab, and HA VLANs
        iifname { "vlan-private", "vlan-lab", "vlan-ha" } \
          oifname { "vlan-private", "vlan-lab", "vlan-ha" } \
          udp dport 5353 accept

        # Private VLAN
        iifname "vlan-private" accept

        # Lab VLAN
        iifname "vlan-lab" accept

        # Tailscale
        iifname "tailscale0" accept

        # Public VLAN
        iifname "vlan-public" oifname "ppp0"                                    accept
        iifname "vlan-public" oifname "vlan-hosted"                             accept
        iifname "vlan-public" ip  daddr 10.101.3.20  tcp dport 443              accept

        # Hosted VLAN
        iifname "vlan-hosted" oifname "ppp0" tcp dport @hosted_out_tcp          accept
        iifname "vlan-hosted" oifname "ppp0" udp dport @hosted_out_udp          accept
        iifname "vlan-hosted" ip daddr 10.101.3.20  tcp dport 443               accept
        iifname "vlan-hosted" ip daddr 10.101.3.21  tcp dport { 443, 9090 }     accept

        # WAN -> Hosted VLAN (inbound to publicly routed /29, no NAT)
        iifname "ppp0" oifname "vlan-hosted" accept

        # WAN Inbound IPv6
        iifname "ppp0" oifname "vlan-private" tcp dport 51413 accept  # QBittorrent
        iifname "ppp0" oifname "vlan-private" udp dport 51413 accept  # QBittorrent

        # Log drops
        log prefix "nft-forward-drop: " flags all
      }
    }

    # IPv4 NAT only
    table ip nat {

      chain prerouting {
        type nat hook prerouting priority -100;

        # Hosted /29 is publicly routed - skip all NAT rules
        iifname "ppp0" ip daddr 217.169.25.8/29 return

        # ppp0 NAT rules (81.187.48.147)

        # HTTPS -> svc-01
        iifname "ppp0" fib daddr . iif type local tcp dport 443 dnat to 10.101.3.20:8443
        iifname "ppp0" fib daddr . iif type local udp dport 443 dnat to 10.101.3.20:8443

        # DNS -> ns1 (for HE secondary nameservers only)
        iifname "ppp0" fib daddr . iif type local ip saddr 216.218.133.2 tcp dport 53 dnat to 10.101.1.2
        iifname "ppp0" fib daddr . iif type local ip saddr 216.218.133.2 udp dport 53 dnat to 10.101.1.2

        # BitTorrent -> QBittorrent
        iifname "ppp0" fib daddr . iif type local tcp dport 51413 dnat to 10.101.3.16
        iifname "ppp0" fib daddr . iif type local udp dport 51413 dnat to 10.101.3.16

        # AARP -> JRouter
        iifname "ppp0" fib daddr . iif type local udp dport 387 dnat to 10.101.3.21
      }

      chain postrouting {
        type nat hook postrouting priority 100;

        # NAT IPv4 out of WAN
        # 217.169.25.8/29 (hosted) is excluded.
        oifname "ppp0" ip saddr 10.0.0.0/8 masquerade
      }
    }
  '';
}
