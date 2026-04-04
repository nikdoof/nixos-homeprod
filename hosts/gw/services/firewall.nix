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

        iif lo accept

        # Drop RFC1918 and other bogon source addresses arriving from WAN (anti-spoofing)
        # Note: fe80::/10 (link-local) is intentionally permitted for DHCPv6 relay on ppp0
        iifname "ppp0" ip  saddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8, 169.254.0.0/16 } drop
        iifname "ppp0" ip6 saddr { ::1/128, fc00::/7 } drop

        ct state established,related accept
        ct state invalid drop

        # TCP flag validation — drop malformed packets used in scanning/fingerprinting
        tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 drop
        tcp flags & (fin|syn) == (fin|syn) drop
        tcp flags & (syn|rst) == (syn|rst) drop
        tcp flags & (fin|rst) == (fin|rst) drop
        tcp flags & (fin|ack) == fin drop
        tcp flags & (urg|ack) == urg drop
        tcp flags & (psh|ack) == psh drop

        # ICMPv4
        ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } \
          limit rate 10/second accept

        # ICMPv6 — restricted to required types only
        ip6 nexthdr icmpv6 icmpv6 type {
          destination-unreachable, packet-too-big,
          time-exceeded, parameter-problem,
          nd-router-solicit, nd-router-advert,
          nd-neighbor-solicit, nd-neighbor-advert,
          echo-request, echo-reply,
          mld-listener-query, mld-listener-report
        } limit rate 10/second accept

        # DHCPv4 server
        iifname { "vlan-private", "vlan-public", "vlan-lab", "vlan-ha", "vlan-hosted" } \
          ip protocol udp udp dport 67 accept

        # DHCPv6 server
        iifname { "vlan-private", "vlan-public", "vlan-lab", "vlan-hosted" } udp dport 547 accept

        # DHCPv6 client on WAN — only accept replies from link-local relay on port 547
        iifname "ppp0" ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept

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

        # WAN input drops
        iifname "ppp0" counter name fw_wan_input_drop drop
      }

      # Named counters — exported to Prometheus via the nftables textfile collector.
      counter fw_wan_input_drop   { comment "WAN packets dropped in input chain (ppp0 input)" }
      counter fw_wan_forward_drop { comment "WAN inbound packets dropped (ppp0 forward chain)" }
      counter fw_hosted_blocked   { comment "Hosted VLAN outbound packets blocked" }
      counter fw_forward_drop     { comment "All other forward chain drops (logged)" }

      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop

        # TCP flag validation — drop malformed packets used in scanning/fingerprinting
        tcp flags & (fin|syn|rst|psh|ack|urg) == 0x0 drop
        tcp flags & (fin|syn) == (fin|syn) drop
        tcp flags & (syn|rst) == (syn|rst) drop
        tcp flags & (fin|rst) == (fin|rst) drop
        tcp flags & (fin|ack) == fin drop
        tcp flags & (urg|ack) == urg drop
        tcp flags & (psh|ack) == psh drop

        # ICMPv6 — transit types only; NDP and MLD are link-local and must not be forwarded
        ip6 nexthdr icmpv6 icmpv6 type {
          destination-unreachable, packet-too-big,
          time-exceeded, parameter-problem,
          echo-request, echo-reply
        } limit rate 10/second accept

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

        # Private VLAN — full outbound access including to hosted
        iifname "vlan-private" accept

        # Lab VLAN — block lateral movement to private and HA; allow hosted and WAN
        iifname "vlan-lab" oifname "vlan-private" drop
        iifname "vlan-lab" oifname "vlan-ha"      drop
        iifname "vlan-lab" accept

        # Tailscale
        iifname "tailscale0" accept

        # Public VLAN
        iifname "vlan-public" oifname "ppp0"                                    accept
        iifname "vlan-public" oifname "vlan-hosted" tcp dport { 80, 443 }       accept
        iifname "vlan-public" oifname "vlan-hosted"                             drop
        iifname "vlan-public" ip  daddr 10.101.3.20  tcp dport 443              accept

        # Hosted VLAN
        iifname "vlan-hosted" oifname "ppp0" tcp dport @hosted_out_tcp          accept
        iifname "vlan-hosted" oifname "ppp0" udp dport @hosted_out_udp          accept
        iifname "vlan-hosted" ip daddr 10.101.3.20  tcp dport 443               accept
        iifname "vlan-hosted" ip daddr 10.101.3.21  tcp dport { 443, 9090 }     accept
        iifname "vlan-hosted" udp dport 41641                                   accept
        # Count hosted VLAN packets that fell through all accept rules
        iifname "vlan-hosted" counter name fw_hosted_blocked

        # WAN -> Hosted VLAN (inbound to publicly routed /29, no NAT)
        iifname "ppp0" oifname "vlan-hosted" accept

        # WAN Inbound IPv6
        iifname "ppp0" oifname "vlan-private" tcp dport 51413 accept  # QBittorrent
        iifname "ppp0" oifname "vlan-private" udp dport 51413 accept  # QBittorrent

        # WAN inbound drops - count without logging (suppress noise)
        iifname "ppp0" counter name fw_wan_forward_drop drop
        # Log and count all remaining (internal) drops
        log prefix "nft-forward-drop: " flags all counter name fw_forward_drop
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
