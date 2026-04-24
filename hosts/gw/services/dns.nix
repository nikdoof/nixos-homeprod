_: {
  services.unbound = {
    enable = true;
    settings = {
      server = {
        # Listen only on the hosted VLAN interface
        interface = [
          "217.169.25.9"
          "2001:8b0:bd9:106::1"
        ];
        access-control = [
          "0.0.0.0/0 refuse"
          "::/0 refuse"
          "217.169.25.8/29 allow"
          "2001:8b0:bd9:106::/64 allow"
        ];

        # Don't leak version / hostname via CHAOS queries.
        hide-identity = true;
        hide-version = true;

        # Reject malformed / DNSSEC-stripped / inconsistent-referral responses.
        harden-glue = true;
        harden-dnssec-stripped = true;
        harden-referral-path = true;
        harden-below-nxdomain = true;

        # Send only the minimum qname to each upstream authority.
        qname-minimisation = true;

        # 0x20-bit case randomisation to harden against cache poisoning.
        use-caps-for-id = true;

        # Refresh popular records before TTL expiry.
        prefetch = true;

        # Belt-and-braces caps: the ACL already scopes queries to the hosted
        # ranges, but if a firewall rule ever leaks these bound the
        # amplification potential.
        ratelimit = 1000;
        ip-ratelimit = 200;
      };
      forward-zone = [
        {
          name = ".";
          forward-addr = [
            "10.101.1.2"
            "10.101.1.3"
            "2001:8b0:bd9:101::2"
            "2001:8b0:bd9:101::3"
          ];
        }
      ];
    };
  };
}
