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

        # ICMPv4 — rate-limited to mitigate reflection floods
        ip protocol icmp limit rate 10/second accept

        # ICMPv6 — unrestricted; required for NDP, RA, PMTUD, MLD
        ip6 nexthdr icmpv6 accept

        # DHCPv4 server — VLAN interfaces only (not WAN)
        iif { vlan-private, vlan-public, vlan-lab, vlan-ha, vlan-hosted } udp dport 67 accept

        # DHCPv6 server — IPv6-enabled VLANs (HA is IPv4-only)
        iif { vlan-private, vlan-public, vlan-lab, vlan-hosted } udp dport 547 accept

        # DNS — internal networks
        ip  saddr @local4 tcp dport { 53, 853 } accept
        ip  saddr @local4 udp dport 53          accept
        ip6 saddr @local6 tcp dport { 53, 853 } accept
        ip6 saddr @local6 udp dport 53          accept

        # DNS — HE secondaries (zone transfer / NOTIFY inbound to gateway;
        #       DNAT in prerouting forwards these to ns1 at 10.101.1.2)
        ip  saddr @he_dns4 tcp dport 53 accept
        ip6 saddr @he_dns6 tcp dport 53 accept

        # NTP — internal networks
        ip  saddr @local4 udp dport 123 accept
        ip6 saddr @local6 udp dport 123 accept

        # SSH — private VLAN only
        iif vlan-private tcp dport 22 accept
      }

      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop

        # ICMPv6 must be forwarded for NDP proxying, PMTUD, and diagnostics
        ip6 nexthdr icmpv6 accept

        # Block 2001:8b0:bd9:300::/64 from reaching addresses outside the /48
        # (pfSense "Log Thread" rule — prevents this subnet escaping to the internet)
        ip6 saddr 2001:8b0:bd9:300::/64 ip6 daddr != 2001:8b0:bd9::/48 drop

        # Allow all traffic that has been DNAT'd in prerouting (port forwards)
        ct status dnat accept

        # Private VLAN — unrestricted outbound (LAN admin network)
        iif vlan-private accept

        # Lab VLAN — unrestricted outbound (pfSense floating "Allow All")
        iif vlan-lab accept

        # Public VLAN — internet + specific internal services only
        iif vlan-public oif ppp0                                    accept
        iif vlan-public ip  daddr 10.101.3.20  tcp dport 443       accept

        # HA VLAN — no forwarding; hosts only reach the gateway itself (INPUT)

        # Hosted VLAN — publicly routable /29; restricted outbound
        iif vlan-hosted oif ppp0 tcp dport @hosted_out_tcp         accept
        iif vlan-hosted oif ppp0 udp dport @hosted_out_udp         accept
        iif vlan-hosted ip daddr 10.101.3.20  tcp dport 443        accept
        iif vlan-hosted ip daddr 10.101.3.21  tcp dport { 443, 9090 } accept

        # WAN → Hosted VLAN (inbound to publicly routed /29, no NAT)
        iif ppp0 oif vlan-hosted accept

        # mDNS (Bonjour/Avahi) between private, lab, and HA VLANs
        iif { vlan-private, vlan-lab, vlan-ha } \
          oif { vlan-private, vlan-lab, vlan-ha } \
          udp dport 5353 accept
      }
    }

    # IPv4 NAT only — IPv6 is natively routed from the static /48
    table ip nat {

      chain prerouting {
        type nat hook prerouting priority -100;

        # HTTPS → svc-01 (WAN dynamic IP; remainder of :443 on ppp0)
        iif ppp0 tcp dport 443 dnat to 10.101.3.20:8443
        iif ppp0 udp dport 443 dnat to 10.101.3.20:8443

        # DNS → ns1 (for HE secondary nameservers only)
        iif ppp0 ip saddr 216.218.133.2 tcp dport 53 dnat to 10.101.1.2
        iif ppp0 ip saddr 216.218.133.2 udp dport 53 dnat to 10.101.1.2

        # BitTorrent → QBittorrent
        iif ppp0 tcp dport 51413 dnat to 10.101.3.16:32710
        iif ppp0 udp dport 51413 dnat to 10.101.3.16:32710

        # JRouter discovery port
        iif ppp0 udp dport 387 dnat to 10.101.3.21:387
      }

      chain postrouting {
        type nat hook postrouting priority 100;

        # Masquerade all RFC1918 traffic leaving via WAN.
        # 217.169.25.8/29 (hosted) is excluded — it is publicly routable.
        oif ppp0 ip saddr 10.0.0.0/8 masquerade
      }
    }
  '';
}
