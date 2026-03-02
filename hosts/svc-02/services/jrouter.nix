{ ... }:
{

  imports = [
    ../../../modules/jrouter.nix
    ../../../packages
  ];

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
      #peerlist_url = "";
    };
  };
}
