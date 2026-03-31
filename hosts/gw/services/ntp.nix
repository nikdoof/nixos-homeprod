_: {
  # Chrony NTP server — gw advertises itself as 10.101.1.1 in DHCP NTP option.
  # Upstream servers: UK/AA.net NTP pool from pfSense config.
  services.chrony = {
    enable = true;
    servers = [
      "chronos.csr.net"
      "ntp2c.mcc.ac.uk"
      "time.aa.net.uk"
      "ntp1.npl.co.uk"
      "ntp2d.mcc.ac.uk"
      "ntp2.npl.co.uk"
    ];
    extraConfig = ''
      # Serve time to all internal networks
      allow 10.0.0.0/8
      allow 2001:8b0:bd9::/48
      allow fc00::/7

      # Step the clock on the first 3 updates if off by more than 1 second
      # (fast correction on boot before ntpd has enough samples to slew)
      makestep 1.0 3
    '';
  };
}
