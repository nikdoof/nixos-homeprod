{ ... }:
let
  dns_masters = [ "10.101.1.2" ];
  dns_slaves = [ "10.101.1.3" ];

  mkDnsDomain = zone: {
    master = false;
    masters = dns_masters;
    slaves = dns_slaves;
    file = "/etc/bind/zones/${zone}.db";
  };
in
{
  networking.firewall.allowedTCPPorts = [ 53 ];
  networking.firewall.allowedUDPPorts = [ 53 ];

  services.bind = {
    enable = true;

    cacheNetworks = [
      "10.0.0.0/8"
      "2001:8b0:bd9::/48"
      "fddd:d00f:dab0::/48"
    ];

    extraConfig = ''
      // Stats channel for prometheus-bind-exporter
      statistics-channels {
        inet 127.0.0.1 port 8053 allow { 127.0.0.1; };
      };

      // HE.net DNS Servers
      acl "he-dns" {
          216.218.133.2;
          2001:470:600::2;
      };
    '';

    zones = {
      "rpz" = mkDnsDomain "rpz";
      "101.10.in.addr.arpa" = mkDnsDomain "101.10.in.addr.arpa";
      "102.10.in.addr.arpa" = mkDnsDomain "102.10.in.addr.arpa";
      "104.10.in.addr.arpa" = mkDnsDomain "104.10.in.addr.arpa";
      "105.10.in.addr.arpa" = mkDnsDomain "105.10.in.addr.arpa";
      "147.48.187.81.in-addr.arpa" = mkDnsDomain "147.48.187.81.in-addr.arpa";
      "8-15.25.169.217.in-addr.arpa" = mkDnsDomain "8-15.25.169.217.in-addr.arpa";
      "1.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa" = mkDnsDomain "1.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa";
      "2.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa" = mkDnsDomain "2.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa";
      "4.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa" = mkDnsDomain "4.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa";
      "6.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa" = mkDnsDomain "6.0.1.0.9.d.b.0.0.b.8.0.1.0.0.2.ip6.arpa";
      "0.b.a.d.f.0.0.d.d.d.d.f.ip6.arpa" = mkDnsDomain "0.b.a.d.f.0.0.d.d.d.d.f.ip6.arpa";
      "int.doofnet.uk" = mkDnsDomain "int.doofnet.uk";
      "pub.doofnet.uk" = mkDnsDomain "pub.doofnet.uk";
      "lab.doofnet.uk" = mkDnsDomain "lab.doofnet.uk";
      "ha.doofnet.uk" = mkDnsDomain "ha.doofnet.uk";
      "prod.doofnet.uk" = mkDnsDomain "prod.doofnet.uk";
      "svc.doofnet.uk" = mkDnsDomain "svc.doofnet.uk";
      "mfg.cobaltmicro.com" = mkDnsDomain "mfg.cobaltmicro.com";
    };
  };

  services.prometheus.exporters.bind = {
    enable = true;
    openFirewall = true;
  };
}
