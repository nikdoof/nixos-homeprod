_: {

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
      peerlist_url = "https://gist.githubusercontent.com/nikdoof/976fc87b0d7abd3e5ec6f583e0b202db/raw/de73d44a0ca505253743ff5a418f000b79a8d129/gistfile1.txt";
    };
  };

  networking.firewall.allowedTCPPorts = [ 9459 ];
}
