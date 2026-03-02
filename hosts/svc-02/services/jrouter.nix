{ ... }:
{

  imports = [
    ../../../modules/jrouter.nix
    ../../../packages
  ];

  networking.firewall.allowedUDPPorts = [ 387 ];

  services.jrouter = {
    enable = true;

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
}
