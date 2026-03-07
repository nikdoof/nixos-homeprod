{ ... }:
{

  imports = [
    ../../../modules/jrouter.nix
    ../../../packages
  ];

  services.jrouter = {
    enable = true;
    openFirewall = true;

    settings = {
      local_ip = "81.187.48.147";
      monitoring_addr = ":9459";
      ethertalk = [
        {
          device = "eno1";
          zone_name = "Doofnet";
          net_start = 28648;
          net_end = 28648;
        }
      ];
      open_peering = true;
      peers = [ ];
      peerlist_url = "https://gist.githubusercontent.com/nikdoof/976fc87b0d7abd3e5ec6f583e0b202db/raw/15bf11edf13860f151a04c2a9cf2808d40226577/gistfile1.txt";
    };
  };

  networking.firewall.extraCommands = ''
    # Allow JRouter metrics port from Prometheus system
    iptables -A INPUT -p tcp --dport 9459 -s 10.101.0.0/16 -j ACCEPT -m comment --comment "Prometheus access to jrouter metrics"
    ip6tables -A INPUT -p tcp --dport 9459 -s fddd:d00f:dab0:101::/64 -j ACCEPT -m comment --comment "Prometheus access to jrouter metrics"
    ip6tables -A INPUT -p tcp --dport 9459 -s 2001:8b0:bd9:101::21/64 -j ACCEPT -m comment --comment "Prometheus access to jrouter metrics"
  '';
}
